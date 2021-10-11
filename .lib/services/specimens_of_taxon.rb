# frozen_string_literal: true

class SpecimensOfTaxon
    def self.fill_hash(specimens_of_taxon:, specimen_object:)
        taxon_name              = specimen_object.taxon_name
        identifier              = specimen_object.identifier
        sequence                = specimen_object.sequence
        first_specimen_info     = specimen_object.first_specimen_info
        nomial                  = specimen_object.nomial
        location                = specimen_object.location
        latitude                = specimen_object.lat
        longitude               = specimen_object.long
        
        specimen                = Hash.new
        specimen[:identifier]   = identifier
        specimen[:sequence]     = sequence
        specimen[:location]     = location
        specimen[:latitude]     = latitude
        specimen[:longitude]    = longitude

        if specimens_of_taxon.key?(taxon_name)
            specimens_of_taxon[taxon_name][:data].push(specimen)
        else
            specimens_of_taxon[taxon_name][:nomial]                 = nomial
            specimens_of_taxon[taxon_name][:first_specimen_info]    = first_specimen_info
            specimens_of_taxon[taxon_name][:data]                   = [specimen]
            specimens_of_taxon[taxon_name][:obj]                    = specimen_object
        end

        return specimens_of_taxon
    end
end