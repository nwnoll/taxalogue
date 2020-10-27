# frozen_string_literal: true

class OutputFormat::Fasta
    extend StringFormatting

    def self.write_to_file(fasta:, data:, taxonomic_info:)
        fasta.puts _fasta_header(data: data, taxonomic_info: taxonomic_info)
        fasta.puts _fasta_seq(data: data)
    end
end

class OutputFormat::MergedFasta; end
