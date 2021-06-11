# frozen_string_literal: true

class OutputFormat::Synonyms

    def self.write_to_file(file:, accepted_taxon:, synonyms_of_taxonomy:)
    
        file.puts accepted_taxon.scientific_name
        synonyms_of_taxonomy.each do |taxonomy, synonyms|
            synonyms.each do |synonym|
                file.puts "\t#{synonym.scientific_name}"
            end
        end
        file.puts
    end
end