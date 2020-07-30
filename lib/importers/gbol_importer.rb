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

  ## change to Zip processing
  ## or unzip file to use csv
  def run

    seqs_and_ids_by_taxon_name = Hash.new
    file                       = File.open(file_name, 'r')
    
    csv_object.each do |row|
      specimen = Specimen.new
      specimen.identifier = row["CatalogueNumber"]
      specimen.sequence   = row['BarcodeSequence']
      specimen.taxon_name = row["Species"]
      SpecimensOfTaxon.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name: seqs_and_ids_by_taxon_name, specimen_object: specimen)
    end


    tsv   = File.open("results/#{query_taxon}_gbol_output.tsv", 'w')
    fasta = File.open("results/#{query_taxon}_gbol_output.fas", 'w')
    
    seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
      nomial          = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      taxonomic_info  = nomial.taxonomy
      next unless taxonomic_info
      next unless taxonomic_info.public_send(GbifTaxon.rank_mappings["#{query_taxon_rank}"]) == query_taxon

      seqs_and_ids_by_taxon_name[taxon_name].each do |data|
        OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
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
