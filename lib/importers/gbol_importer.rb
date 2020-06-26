# frozen_string_literal: true

require 'csv'
class GbolImporter
  include StringFormatting

  attr_reader :file_name, :query_taxon, :query_taxon_rank

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
    csv_object.each do |row|
      add_values(entry_of, row)
    end
    _generate_outputs(entry_of)
  end

  def add_values(hash, row)
    identifier    = row["CatalogueNumber"]
    lineage       = row["HigherTaxa"]
    lineage       = lineage.delete(' ').split(',')
    species_name  = row['Species']
    sequence      = row['BarcodeSequence']
    if hash.has_key?(species_name)
      hash[species_name].push([identifier, lineage, sequence])
    else
      hash[species_name] = [[identifier, lineage, sequence]]
    end
    return hash
  end

  def _generate_outputs(specimen_data)
    tsv = File.open('gbol_output.tsv', 'w')
    tsv.puts _tsv_header

    fh_o = File.open('gbol_compare_taxonomy.tsv', 'w')
    fh_seqs_o = File.open('gbol_seqs.fas', 'w')
    specimen_data.keys.each do |species_name|
      nomial = Nomial.generate(name: species_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      tax_info = nomial.taxonomy
      unless tax_info
        fh_o.puts "not found: #{species_name}"
        next
      end

      count = 0
      specimen_data[species_name].each do |data|
        count += 1
        fh_o.puts "#{data[0]}|#{data[1].join('|')}|#{species_name}\t#{data[0]}|#{_to_taxon_info(tax_info)}" if count == 1
        tsv.puts _tsv_row(identifier: data[0], lineage_data: tax_info, sequence: data[2])
        fh_seqs_o.puts ">#{data[0]}|#{_to_taxon_info(tax_info)}"
        fh_seqs_o.puts data[2]
      end
    end
  end

  def csv_object
    CSV.new(opened_file_in_read_mode, headers: true, col_sep: "\t", liberal_parsing: true)
  end

  def opened_file_in_read_mode
    file = File.open(file_name, 'r')
  end

  ## UNUSED
  def _find_highest_matching_rank(specimen_data)
    regna         = GbifTaxon.names_for('kingdom')
    lineage       = specimen_data[1] - regna
    highest_match = nil

    lineage.each do |t|
      p "--- #{t}"
      record = GbifTaxon.find_by_canonical_name(t)
      unless record.nil?
        highest_match = t
        break
      end
    end
    p "highest_match: #{highest_match}"
    return highest_match
  end
end
