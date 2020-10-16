# frozen_string_literal: true

class OutputFormat::Synonyms

    def self.write_to_file(file:, accepted_taxon:, synonyms:)
    
        file.puts accepted_taxon.scientific_name
        synonyms.each do |synonym|
            file.puts "\t#{synonym.scientific_name}"
        end
        file.puts
    end
end