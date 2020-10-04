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
    file_count = 0
    file_names = Dir[ 'data/NCBI/sequences/*' ].select{ |f| File.file? f }
    file_names = Dir[ 'data/NCBI/sequences/gbinv38*' ].select{ |f| File.file? f }
    # file_names = Dir[ 'data/ncbigenbank/mam/*' ].select{ |f| File.file? f }
    
    file_names.each do |file|
      file_count                 += 1
      file_name_match             = file.match(/gb\w+\d+/)
      base_name                   = file_name_match[0]
      entry_of                    = Hash.new
      seqs_and_ids_by_taxon_name  = Hash.new
      
      Zlib::GzipReader.open(file) do |gz_file|
        gb_entry = ''.dup
        gz_file.each_line do |line|
          next if gz_file.lineno <= FILE_DESCRIPTION_PART

          gb_entry.concat(line); next if line !~ /#{is_gb_entry_end}/
          gb = Bio::GenBank.new(gb_entry)

          _matches_query_taxon(gb) ? nil : next if fast_run

          features_of_gene = gb.features.select { |f| _is_gene?(f.feature) && _is_gene_of_marker?(f.qualifiers) && _is_no_pseudogene?(f.qualifiers) }
          gb_entry = ''.dup; next unless features_of_gene.size == 1

          specimen            = Specimen.new
          specimen.identifier = gb.accession
          
          nucs                = gb.naseq.splicing(features_of_gene.first.position).to_s
          gb_entry = ''.dup; next if nucs.nil? || nucs.empty?

          specimen.sequence   = nucs
          specimen.taxon_name = gb.organism
          SpecimensOfTaxon.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name: seqs_and_ids_by_taxon_name, specimen_object: specimen)

          gb_entry = ''.dup
        end
      end

      tsv   = File.open("results2/#{query_taxon_name}_ncbi_#{base_name}_fast_#{fast_run}_output_DEBUG.tsv", 'w')
      fasta = File.open("results2/#{query_taxon_name}_ncbi_#{base_name}_fast_#{fast_run}_output_DEBUG.fas", 'w')
    
      seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
        nomial          = Nomial.generate(name: taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)
        taxonomic_info  = nomial.taxonomy
        next unless taxonomic_info
        next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

        seqs_and_ids_by_taxon_name[taxon_name].each do |data|
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

  def _is_gene?(s)
    s == 'gene'
  end

  def _is_gene_of_marker?(qualifiers)
    qualifiers.any? { |q| q.qualifier == 'gene' && regexes_for_markers === q.value}
  end


  def _is_no_pseudogene?(qualifiers)
    qualifiers.none? { |q| q.qualifier == 'pseudo' }
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
