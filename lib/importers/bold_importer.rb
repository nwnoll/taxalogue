# frozen_string_literal: true

require 'benchmark'

class BoldImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon, :query_taxon_rank, :fast_run

  def initialize(file_name:, query_taxon:, query_taxon_rank:, fast_run: true)
    @file_name        = file_name
    @query_taxon      = query_taxon
    @query_taxon_rank = query_taxon_rank
    @fast_run         = fast_run
  end

  def run
    seqs_and_ids_by_taxon_name = Hash.new
    file                       = File.open(file_name, 'r')

    index_by_column_name       = Helper.generate_index_by_column_name(file: file, separator: "\t")

    file.each do |row|
      _matches_query_taxon(row.scrub!) ? nil : next if fast_run

      specimen_data = row.scrub!.chomp.split("\t")


      specimen = Specimen.new
      specimen.identifier   = specimen_data[index_by_column_name["processid"]]
      nucs                  = specimen_data[index_by_column_name['nucleotides']]
      next if nucs.nil? || nucs.empty?

      specimen.sequence     = nucs
      specimen.taxon_name   = SpecimensOfTaxon.find_lowest_ranking_taxon(specimen_data, index_by_column_name)
      SpecimensOfTaxon.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name: seqs_and_ids_by_taxon_name, specimen_object: specimen)
    end

    tsv   = File.open("results2/#{query_taxon}_bold_fast_#{fast_run}_output_test.tsv", 'w')
    fasta = File.open("results2/#{query_taxon}_bold_fast_#{fast_run}_output_test.fas", 'w')


    seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
      nomial          = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      taxonomic_info  = nomial.taxonomy
      next unless taxonomic_info
      next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon

      seqs_and_ids_by_taxon_name[taxon_name].each do |data|
        OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
      end
    end
  end

  private
  def _matches_query_taxon(row)
    /#{query_taxon}/.match?(row)
  end
end