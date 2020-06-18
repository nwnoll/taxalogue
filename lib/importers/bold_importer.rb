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
