# frozen_string_literal: true

class BoldImporter
  include OutputFormatting
  attr_reader :file_name, :query_taxon, :query_taxon_rank

  def initialize(file_name:, query_taxon:, query_taxon_rank:)
    @file_name        = file_name
    @query_taxon      = query_taxon
    @query_taxon_rank = query_taxon_rank
  end

  def run
    seqs_and_ids_by_taxon_name = SpecimensOfTaxon.generate(file_name: file_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)

    tsv   = File.open("results/#{query_taxon}_output.tsv", 'w')
    fasta = File.open("results/#{query_taxon}_output.fas", 'w')

    seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
      nomial          = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      taxonomic_info  = nomial.taxonomy
      next unless taxonomic_info

      seqs_and_ids_by_taxon_name[taxon_name].each do |data|
        Output::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        Output::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
      end
    end
  end
end
