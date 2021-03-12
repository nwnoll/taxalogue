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

    def self.find_lowest_ranking_taxon(specimen_data, index_by_column_name)
        _possible_taxa.each do |taxon|
          return specimen_data[index_by_column_name[taxon]] unless specimen_data[index_by_column_name[taxon]].blank?
          return nil if specimen_data[index_by_column_name[taxon]] == _possible_taxa.last
        end
    end

    def self.create_lineage_ary(specimen_data, index_by_column_name)
        lineage_ary = []
        _possible_taxa.reverse.each do |taxon|
            lineage_ary.push(specimen_data[index_by_column_name[taxon]]) unless specimen_data[index_by_column_name[taxon]].blank?
        end

        return lineage_ary
    end

    def self._possible_taxa
        ## BOLD
        ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'class_name', 'phylum_name']
    end
end