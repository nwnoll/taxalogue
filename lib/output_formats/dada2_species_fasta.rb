# frozen_string_literal: true

class OutputFormat::Dada2SpeciesFasta
    extend StringFormatting

    def self.write_to_file(fasta:, data:, taxonomic_info:)
        header = fasta_header_dada2_species(data: data, taxonomic_info:taxonomic_info)
        return nil if header.nil?

        fasta.puts header
        fasta.puts _fasta_seq(data: data)
    end
end

class OutputFormat::MergedDada2SpeciesFasta; end
