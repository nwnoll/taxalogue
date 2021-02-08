# frozen_string_literal: true

class NcbiGenbankImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :markers, :fast_run, :regexes_for_markers, :file_manager, :filter_params, :taxonomy_params

  FILE_DESCRIPTION_PART = 10

  def _possible_taxa
    ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
  end

  def initialize(file_name:, query_taxon_object:, markers:, fast_run: true, file_manager:, filter_params: nil, taxonomy_params:)
    @file_name            = file_name
    @query_taxon_object   = query_taxon_object
    @query_taxon_name     = query_taxon_object.canonical_name
    @query_taxon_rank     = query_taxon_object.taxon_rank
    @markers              = markers
    @fast_run             = fast_run
    @regexes_for_markers  = Marker.regexes(db: self, markers: markers)
    @file_manager         = file_manager
    @filter_params        = filter_params
    @taxonomy_params      = taxonomy_params
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
        ## TODO: catch corrupted files
        ## see if Download has been aborted:
        # /home/nnoll/.rvm/gems/ruby-3.0.0/gems/bio-2.0.1/lib/bio/io/flatfile/buffer.rb:250:in `gets': unexpected end of file (Zlib::GzipFile::Error)
        # from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/bio-2.0.1/lib/bio/io/flatfile/buffer.rb:250:in `gets'
        # from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/bio-2.0.1/lib/bio/io/flatfile/splitter.rb:182:in `get_entry'
        # from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/bio-2.0.1/lib/bio/io/flatfile/splitter.rb:53:in `get_parsed_entry'
        # from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/bio-2.0.1/lib/bio/io/flatfile.rb:288:in `next_entry'
        # from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/bio-2.0.1/lib/bio/io/flatfile.rb:335:in `each_entry'
        # from /home/nnoll/phd/db_merger/lib/importers/ncbi_genbank_importer.rb:40:in `block (2 levels) in run'
        # from /home/nnoll/phd/db_merger/lib/importers/ncbi_genbank_importer.rb:37:in `open'
        # from /home/nnoll/phd/db_merger/lib/importers/ncbi_genbank_importer.rb:37:in `block in run'
        # from /home/nnoll/phd/db_merger/lib/importers/ncbi_genbank_importer.rb:32:in `each'
        # from /home/nnoll/phd/db_merger/lib/importers/ncbi_genbank_importer.rb:32:in `run'
        # from /home/nnoll/phd/db_merger/lib/jobs/ncbi_genbank_job.rb:112:in `block (2 levels) in _classify_downloads'
        # from /home/nnoll/phd/db_merger/lib/jobs/ncbi_genbank_job.rb:108:in `each'
        # from /home/nnoll/phd/db_merger/lib/jobs/ncbi_genbank_job.rb:108:in `block in _classify_downloads'
        # from /home/nnoll/phd/db_merger/lib/jobs/ncbi_genbank_job.rb:104:in `each'
        # from /home/nnoll/phd/db_merger/lib/jobs/ncbi_genbank_job.rb:104:in `_classify_downloads'
        # from /home/nnoll/phd/db_merger/lib/jobs/ncbi_genbank_job.rb:21:in `run'
        # from main.rb:148:in `<main>'

        ff = Bio::FlatFile.new(Bio::GenBank, gz_file)

        ff.each_entry do |gb|
          _matches_query_taxon(gb) ? nil : next if fast_run
          
          features_of_gene  = gb.features.select { |f| _is_gene_feature?(f.feature) && _is_gene_of_marker?(f.qualifiers) && _is_no_pseudogene?(f.qualifiers) }
          next unless features_of_gene.size == 1 ## TODO: why 1 ?
          
          nucs = gb.naseq.splicing(features_of_gene.first.position).to_s
          next if nucs.nil? || nucs.empty?

          nucs = Helper.filter_seq(nucs, filter_params)
          next if nucs.nil? || nucs.empty?

          nucs.upcase!

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
        syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [Helper.get_source_db(taxonomy_params)])
        # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms: syn.synonyms)

        OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms: syn.synonyms[Helper.get_source_db(taxonomy_params)], used_taxonomy: Helper.get_source_db(taxonomy_params) )

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
    nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)

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
