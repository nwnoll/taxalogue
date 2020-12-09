# frozen_string_literal: true

class NcbiGenbankImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :markers, :fast_run, :regexes_for_markers, :file_manager

  FILE_DESCRIPTION_PART = 10

  def _possible_taxa
    ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
  end

  def initialize(file_name:, query_taxon_object:, markers:, fast_run: true, file_manager:)
    @file_name            = file_name
    @query_taxon_object   = query_taxon_object
    @query_taxon_name     = query_taxon_object.canonical_name
    @query_taxon_rank     = query_taxon_object.taxon_rank
    @markers              = markers
    @fast_run             = fast_run
    @regexes_for_markers  = Marker.regexes(db: self, markers: markers)
    @file_manager         = file_manager
  end


  def run
    ## TODO: change to one file per run or both
    file_names = []
    file_names.push(file_name)

    file_names.each do |file|
      file_name_match             = file.to_s.match(/gb\w+\d+/)
      base_name                   = file_name_match[0]
      specimens_of_taxon          = Hash.new { |hash, key| hash[key] = {} }
      
      Zlib::GzipReader.open(file) do |gz_file|
        ff = Bio::FlatFile.new(Bio::GenBank, gz_file)

        ff.each_entry do |gb|
          _matches_query_taxon(gb) ? nil : next if fast_run
          
          features_of_gene  = gb.features.select { |f| _is_gene_feature?(f.feature) && _is_gene_of_marker?(f.qualifiers) && _is_no_pseudogene?(f.qualifiers) }
          next unless features_of_gene.size == 1 ## why 1 ?
          
          nucs = gb.naseq.splicing(features_of_gene.first.position).to_s
          next if nucs.nil? || nucs.empty?

          specimen = _get_specimen(gb: gb, nucs: nucs)
          SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
        end
      end

      tsv             = file_manager.create_file("#{query_taxon_name}_#{file_name.basename.sub(/\..*/, '')}_ncbi_fast_#{fast_run}_output.tsv", OutputFormat::Tsv)
      fasta           = file_manager.create_file("#{query_taxon_name}_#{file_name.basename.sub(/\..*/, '')}_ncbi_fast_#{fast_run}_output.fas", OutputFormat::Fasta)
      comparison_file = file_manager.create_file("#{query_taxon_name}_#{file_name.basename.sub(/\..*/, '')}_ncbi_fast_#{fast_run}_comparison.tsv", OutputFormat::Comparison)
  
      specimens_of_taxon.keys.each do |taxon_name|
        nomial              = specimens_of_taxon[taxon_name][:nomial]
        first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
        taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)

        
        next unless taxonomic_info
        next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

        # Synonym List
        # syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [GbifTaxon])
        # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms: syn.synonyms)

        OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info)

        specimens_of_taxon[taxon_name][:data].each do |data|
          OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
          OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
        end
      end

      OutputFormat::Tsv.rewind

      tsv.close
      fasta.close
      comparison_file.close
    end
  end

  def is_gb_entry_end
    "\/\/"
  end

  private

  def _is_gene_feature?(s)
    s == 'gene'
  end

  def self._is_source_feature?(s)
    s == 'source'
  end

  def _is_gene_of_marker?(qualifiers)
    qualifiers.any? { |q| q.qualifier == 'gene' && regexes_for_markers === q.value}
  end

  def _is_no_pseudogene?(qualifiers)
    qualifiers.none? { |q| q.qualifier == 'pseudo' }
  end

  def self._is_db_taxon_xref_qualifier?(qualifier)
    qualifier.qualifier == 'db_xref' && /^taxon:/ === qualifier.value
  end

  def _get_ncbi_ranked_lineage(gb)
    source_feature      = gb.features.select { |f| _is_source_feature?(f.feature) }.first
    taxon_db_xref       = source_feature.qualifiers.select { |q| _is_db_taxon_xref_qualifier?(q) }.first
    ncbi_taxon_id       = taxon_db_xref.value.gsub('taxon:', '').to_i

    ranked = NcbiRankedLineage.find_by(tax_id: ncbi_taxon_id)
    return ranked
  end

  def _get_specimen(gb:, nucs:)
    source_taxon_name             = gb.organism
    nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)

    specimen                      = Specimen.new
    specimen.identifier           = gb.accession
    specimen.sequence             = nucs
    specimen.source_taxon_name    = source_taxon_name
    specimen.taxon_name           = nomial.name
    specimen.nomial               = nomial
    specimen.first_specimen_info  = gb
    return specimen
  end

  def self.get_source_lineage(gb)
    OpenStruct.new(
      name: gb.organism,
      combined: gb.classification
    )
  end

  def _matches_query_taxon(gb)
    /#{query_taxon_name}/.match?(gb.taxonomy) || /#{query_taxon_name}/.match?(gb.organism)
  end

  ## UNUSED
  def _lowest_rank(row, element_of)
    _possible_taxa.each do |t|
      return row[element_of[t]] unless row[element_of[t]].blank?
      return nil if row[element_of[t]] == _possible_taxa.last
    end
  end
end
