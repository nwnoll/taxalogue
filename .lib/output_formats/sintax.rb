# frozen_string_literal: true

class OutputFormat::SintaxFasta
    extend StringFormatting

    def self.write_to_file(fasta:, data:, taxonomic_info:)

        header = _fasta_header_sintax(data: data, taxonomic_info: taxonomic_info)
        return nil if header.nil?
        
        fasta.puts header
        fasta.puts _fasta_seq(data: data)
    end
end

class OutputFormat::MergedSintaxFasta; end
