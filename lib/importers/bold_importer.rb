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

    _generate_outputs(seqs_and_ids_by_taxon_name)
  end

  def _generate_outputs(seqs_and_ids_by_taxon_name)
    tsv   = File.open('bold_output.tsv', 'w')
    fasta = File.open('bold_seqs.fas', 'w')

    # tsv.puts _tsv_header

    seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
      nomial          = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      taxonomic_info  = nomial.taxonomy
      next unless taxonomic_info

      seqs_and_ids_by_taxon_name[taxon_name].each do |data|
        Output::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        fasta.puts ">#{data[0]}|#{_to_taxon_info(taxonomic_info)}"
        fasta.puts data[1]
      end
    end
  end
end
