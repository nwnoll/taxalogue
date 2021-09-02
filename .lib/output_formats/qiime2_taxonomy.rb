# frozen_string_literal: true

class OutputFormat::Qiime2Taxonomy
    extend StringFormatting

    def self.write_to_file(file:, taxonomic_info:, identifier:)
        file.puts _qiime2_taxonomy_row(taxonomic_info: taxonomic_info, identifier: identifier)
    end
end

class OutputFormat::MergedQiime2Taxonomy; end
