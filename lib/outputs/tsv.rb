# frozen_string_literal: true

class Output::Tsv
    extend OutputFormatting

    @@count = 0

    def self.write_to_file(tsv:, data:, taxonomic_info:)
        @@count += 1
        
        tsv.puts _tsv_header if @@count ==  1
        tsv.puts _tsv_row(identifier: data[0], lineage_data: taxonomic_info, sequence: data[1])
    end
end