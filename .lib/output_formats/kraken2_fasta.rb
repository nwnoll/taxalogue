# frozen_string_literal: true

class OutputFormat::Kraken2Fasta
    extend StringFormatting

    def self.write_to_file(fasta:, data:, taxonomic_info:)
        fasta.puts _fasta_header_kraken2(data: data, taxonomic_info: taxonomic_info)
        fasta.puts _fasta_seq(data: data)
    end
end

class OutputFormat::MergedKraken2Fasta; end
