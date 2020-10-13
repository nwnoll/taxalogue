# frozen_string_literal: true

class NcbiGenbankImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :markers, :fast_run, :regexes_for_markers

  FILE_DESCRIPTION_PART = 10

  def _possible_taxa
    ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
  end

  def initialize(file_name:, query_taxon_object:, markers:, fast_run: true)
    @file_name            = file_name
    @query_taxon_object   = query_taxon_object
    @query_taxon_name     = query_taxon_object.canonical_name
    @query_taxon_rank     = query_taxon_object.taxon_rank
    @markers              = markers
    @fast_run             = fast_run
    @regexes_for_markers  = Marker.regexes(db: self, markers: markers)
  end


  def run
    p 'asdads'
    file_count = 0
    # file_names = Dir[ 'data/NCBI/sequences/gbinv*' ].select{ |f| File.file? f }
    file_names = Dir[ 'data/ncbigenbank/inv/gbinv*' ].select{ |f| File.file? f }
    already_processed = ['data/ncbigenbank/inv/gbinv12.seq.gz','data/ncbigenbank/inv/gbinv16.seq.gz','data/ncbigenbank/inv/gbinv15.seq.gz','data/ncbigenbank/inv/gbinv1.seq.gz','data/ncbigenbank/inv/gbinv20.seq.gz','data/ncbigenbank/inv/gbinv35.seq.gz','data/ncbigenbank/inv/gbinv36.seq.gz','data/ncbigenbank/inv/gbinv38.seq.gz','data/ncbigenbank/inv/gbinv45.seq.gz','data/ncbigenbank/inv/gbinv54.seq.gz','data/ncbigenbank/inv/gbinv56.seq.gz','data/ncbigenbank/inv/gbinv57.seq.gz','data/ncbigenbank/inv/gbinv58.seq.gz','data/ncbigenbank/inv/gbinv60.seq.gz','data/ncbigenbank/inv/gbinv65.seq.gz','data/ncbigenbank/inv/gbinv66.seq.gz','data/ncbigenbank/inv/gbinv67.seq.gz','data/ncbigenbank/inv/gbinv6.seq.gz','data/ncbigenbank/inv/gbinv70.seq.gz','data/ncbigenbank/inv/gbinv71.seq.gz','data/ncbigenbank/inv/gbinv73.seq.gz','data/ncbigenbank/inv/gbinv74.seq.gz','data/ncbigenbank/inv/gbinv75.seq.gz','data/ncbigenbank/inv/gbinv77.seq.gz','data/ncbigenbank/inv/gbinv7.seq.gz','data/ncbigenbank/inv/gbinv81.seq.gz','data/ncbigenbank/inv/gbinv83.seq.gz','data/ncbigenbank/inv/gbinv87.seq.gz']
    # file_names = Dir[ 'data/NCBI/sequences/gbinv38*' ].select { |f| File.file? f }
    # file_names = Dir[ 'data/ncbigenbank/mam/*' ].select{ |f| File.file? f }
    
    file_names.each do |file|
      p file
      next if already_processed.include?(file)
      file_count                 += 1
      file_name_match             = file.match(/gb\w+\d+/)
      base_name                   = file_name_match[0]
      specimens_of_taxon          = Hash.new { |hash, key| hash[key] = {} }
      
      Zlib::GzipReader.open(file) do |gz_file|
        gb_entry = ''.dup
        gz_file.each_line do |line|
          next if gz_file.lineno <= FILE_DESCRIPTION_PART
          gb_entry.concat(line); next if line !~ /#{is_gb_entry_end}/
          gb = Bio::GenBank.new(gb_entry)

          _matches_query_taxon(gb) ? nil : next if fast_run

          features_of_gene  = gb.features.select { |f| _is_gene_feature?(f.feature) && _is_gene_of_marker?(f.qualifiers) && _is_no_pseudogene?(f.qualifiers) }
          gb_entry = ''.dup; next unless features_of_gene.size == 1 ## why 1 ?
          
          nucs = gb.naseq.splicing(features_of_gene.first.position).to_s
          gb_entry = ''.dup; next if nucs.nil? || nucs.empty?

          specimen = _get_specimen(gb: gb, nucs: nucs)

          SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
          
          puts gz_file.lineno
          gb_entry = ''.dup
          
        end
      end

      tsv   = File.open("results3/#{query_taxon_name}_ncbi_#{base_name}_fast_#{fast_run}_output.tsv", 'w')
      fasta = File.open("results3/#{query_taxon_name}_ncbi_#{base_name}_fast_#{fast_run}_output.fas", 'w')
    
      specimens_of_taxon.keys.each do |taxon_name|
        p taxon_name
        nomial              = specimens_of_taxon[taxon_name][:nomial]
        first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
        taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)

        next unless taxonomic_info
        next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

        specimens_of_taxon[taxon_name][:data].each do |data|
          OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
          OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
        end
      end
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
    nomial                        = Nomial.generate(name: gb.organism, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)

    specimen                      = Specimen.new
    specimen.identifier           = gb.accession
    specimen.sequence             = nucs
    specimen.taxon_name           = nomial.name
    specimen.nomial               = nomial
    specimen.first_specimen_info  = gb
    return specimen
  end

  def self.get_lineage(gb)
    ## Problem is if the sequences are more recent than the taxonomy, it wont find all tax_ids
    ## than it will blow, could catch it but for now i can just give the classification and its good enough

    # byebug if gb.organism == 'Trioza sp. BIOUG11193-E04'
    # source_feature      = gb.features.select { |f| _is_source_feature?(f.feature) }.first
    # taxon_db_xref       = source_feature.qualifiers.select { |q| _is_db_taxon_xref_qualifier?(q) }.first
    # ncbi_taxon_id       = taxon_db_xref.value.gsub('taxon:', '').to_i
    # ncbi_taxon_rank     = NcbiNode.find_by(tax_id: ncbi_taxon_id).rank
    # ncbi_ranked_lineage = NcbiRankedLineage.find_by(tax_id: ncbi_taxon_id)

    # lineage = Lineage.new(
    #   name:     ncbi_ranked_lineage.name,
    #   species:  ncbi_ranked_lineage.species,
    #   genus:    ncbi_ranked_lineage.genus,
    #   familia:  ncbi_ranked_lineage.familia,
    #   ordo:     ncbi_ranked_lineage.ordo,
    #   classis:  ncbi_ranked_lineage.classis,
    #   phylum:   ncbi_ranked_lineage.phylum,
    #   combined: gb.classification,
    #   rank:     ncbi_taxon_rank,
    # )
    #
    lineage = Lineage.new(
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
