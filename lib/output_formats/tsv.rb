# frozen_string_literal: true

class OutputFormat::Tsv
    extend StringFormatting

    @@count = 0

    def self.write_to_file(tsv:, data:, taxonomic_info:)
        @@count += 1
        
        tsv.puts _tsv_header_all_standard_ranks if @@count ==  1
        tsv.puts _tsv_row_all_standard_ranks(identifier: data[:identifier], lineage_data: taxonomic_info, sequence: data[:sequence], loc: data[:location], lat: data[:latitude], long: data[:longitude])
    end

    def self.rewind
        @@count = 0
    end
end

class OutputFormat::MergedTsv; end