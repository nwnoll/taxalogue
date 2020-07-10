# frozen_string_literal: true

class BoldImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon, :query_taxon_rank

  def initialize(file_name:, query_taxon:, query_taxon_rank:)
    @file_name        = file_name
    @query_taxon      = query_taxon
    @query_taxon_rank = query_taxon_rank
  end

  def run
    seqs_and_ids_by_taxon_name = Hash.new
    file                       = File.open(file_name, 'r')

    index_by_column_name       = Helper.generate_index_by_column_name(file: file, separator: "\t")

    file.each do |row|
        specimen_data = row.scrub!.chomp.split("\t")

        specimen = Specimen.new
        specimen.identifier   = specimen_data[index_by_column_name["processid"]]
        specimen.sequence     = specimen_data[index_by_column_name['nucleotides']]
        specimen.taxon_name   = SpecimensOfTaxon.find_lowest_ranking_taxon(specimen_data, index_by_column_name)
        SpecimensOfTaxon.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name: seqs_and_ids_by_taxon_name, specimen_object: specimen)
      end


    tsv   = File.open("results/#{query_taxon}_output.tsv", 'w')
    fasta = File.open("results/#{query_taxon}_output.fas", 'w')

    seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
      nomial          = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      taxonomic_info  = nomial.taxonomy
      next unless taxonomic_info

      seqs_and_ids_by_taxon_name[taxon_name].each do |data|
        OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
      end
    end
  end
end
