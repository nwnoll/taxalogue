# frozen_string_literal: true

class OutputFormat::Dada2TaxonomyFasta
    extend StringFormatting

    def self.write_to_file(fasta:, data:, taxonomic_info:)
        fasta.puts _fasta_header_dada2_taxonomy(taxonomic_info: taxonomic_info)
        fasta.puts _fasta_seq(data: data)
    end
end

class OutputFormat::MergedDada2TaxonomyFasta; end
