# frozen_string_literal: true

class OutputFormat::Tsv
    extend StringFormatting

    @@count = 0

    def self.write_to_file(tsv:, data:, taxonomic_info:)
        @@count += 1
        
        tsv.puts _tsv_header if @@count ==  1
        tsv.puts _tsv_row(identifier: data[:identifier], lineage_data: taxonomic_info, sequence: data[:sequence], loc: data[:location], lat: data[:latitude], long: data[:longitude])
    end

    def self.rewind
        @@count = 0
    end
end

class OutputFormat::MergedTsv; end