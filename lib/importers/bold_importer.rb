# frozen_string_literal: true

require 'csv'
class BoldImporter
  include OutputFormatting

  attr_reader :file_name, :query_taxon, :query_taxon_rank

  def _possible_taxa
    ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
  end

  def initialize(file_name:, query_taxon:, query_taxon_rank:)
    @file_name        = file_name
    @query_taxon      = query_taxon
    @query_taxon_rank = query_taxon_rank
  end

  def run
    seqs_and_ids_by_taxon_name = Hash.new
    file                       = File.open(file_name, 'r')

    index_by_column_name       = generate_index_by_column_name(file: file)

    file.each do |row|
      specimen_data = row.scrub!.chomp.split("\t")
      fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name, specimen_data, index_by_column_name)
    end

    _generate_outputs(seqs_and_ids_by_taxon_name)
  end

  def generate_index_by_column_name(file:)
    column_names          =  file.first.chomp.split("\t")
    num_columns           = column_names.size
    index_by_column_name  = Hash.new
    (0...num_columns).each do |index|
      index_by_column_name[column_names[index]] = index
    end

    return index_by_column_name
  end

  def fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name, specimen_data, index_by_column_name)
    identifier    = specimen_data[index_by_column_name["processid"]]
    sequence      = specimen_data[index_by_column_name['nucleotides']]
    taxon_name    = _lowest_rank(specimen_data, index_by_column_name)

    if seqs_and_ids_by_taxon_name.has_key?(taxon_name)
      seqs_and_ids_by_taxon_name[taxon_name].push([identifier, sequence])
    else
      seqs_and_ids_by_taxon_name[taxon_name] = [[identifier, sequence]]
    end

    return seqs_and_ids_by_taxon_name
  end

  def _lowest_rank(specimen_data, index_by_column_name)
    _possible_taxa.each do |taxon|
      return specimen_data[index_by_column_name[taxon]] unless specimen_data[index_by_column_name[taxon]].blank?
      return nil if specimen_data[index_by_column_name[taxon]] == _possible_taxa.last
    end
  end

  def _generate_outputs(specimen_data)
    tsv = File.open('bold_output.tsv', 'w')
    tsv.puts _tsv_header

    fh_seqs_o = File.open('bold_seqs.fas', 'w')
    specimen_data.keys.each do |taxon_name|
      nomial = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      taxonomic_info = nomial.taxonomy
      next unless taxonomic_info

      count = 0
      specimen_data[taxon_name].each do |data|
        count += 1
        tsv.puts _tsv_row(identifier: data[0], lineage_data: taxonomic_info, sequence: data[1])
        fh_seqs_o.puts ">#{data[0]}|#{_to_taxon_info(taxonomic_info)}"
        fh_seqs_o.puts data[1]
      end
    end
  end
end
