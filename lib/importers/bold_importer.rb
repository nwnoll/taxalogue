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

  def self.call(file_name:, query_taxon:, query_taxon_rank:)
    new(file_name: file_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank).call
  end


  def call
    entry_of = Hash.new
    file = File.open(file_name, 'r')
    headers =  file.first.chomp.split("\t")
    num_columns = headers.size
    element_of  = Hash.new
    (0...num_columns).each do |i|
      element_of[headers[i]] = i
    end
    file.each do |row|
      entries = row.scrub!.chomp.split("\t")
      add_values(entry_of, entries, element_of)
    end
    _generate_outputs(entry_of)
  end

  def add_values(hash, row, element_of)
    identifier    = row[element_of["processid"]]
    sequence      = row[element_of['nucleotides']]
    species_name  =  _lowest_rank(row, element_of)
    if hash.has_key?(species_name)
      hash[species_name].push([identifier, sequence])
    else
      hash[species_name] = [[identifier, sequence]]
    end
    return hash
  end

  def _lowest_rank(row, element_of)
    _possible_taxa.each do |t|
      return row[element_of[t]] unless row[element_of[t]].blank?
      return nil if row[element_of[t]] == _possible_taxa.last
    end
  end

  def _generate_outputs(specimen_data)
    tsv = File.open('bold_output.tsv', 'w')
    tsv.puts _tsv_header

    fh_seqs_o = File.open('bold_seqs.fas', 'w')
    specimen_data.keys.each do |species_name|
      nomial = Nomial.generate(name: species_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      tax_info = nomial.taxonomy
      unless tax_info
        puts species_name
        next
      end

      count = 0
      specimen_data[species_name].each do |data|
        count += 1
        tsv.puts _tsv_row(identifier: data[0], lineage_data: tax_info, sequence: data[1])
        fh_seqs_o.puts ">#{data[0]}|#{_to_taxon_info(tax_info)}"
        fh_seqs_o.puts data[1]
      end
    end
  end
end
