# frozen_string_literal: true

class OutputFormat::Qiime2TaxonomyFasta
    extend StringFormatting

    def self.write_to_file(fasta:, data:, taxonomic_info:)
        fasta.puts _fasta_header_qiime2_taxonomy(data: data, taxonomic_info: taxonomic_info)
        fasta.puts _fasta_seq(data: data)
    end
end

class OutputFormat::MergedQiime2TaxonomyFasta; end
