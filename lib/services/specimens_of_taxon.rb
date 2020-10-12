# frozen_string_literal: true

class SpecimensOfTaxon
    def self.fill_hash(specimens_of_taxon:, specimen_object:)
        taxon_name          = specimen_object.taxon_name
        identifier          = specimen_object.identifier
        sequence            = specimen_object.sequence
        first_specimen_info = specimen_object.first_specimen_info
        nomial              = specimen_object.nomial
        
        specimen = Hash.new
        specimen[:identifier] = identifier
        specimen[:sequence]   = sequence

        if specimens_of_taxon.has_key?(taxon_name)
            specimens_of_taxon[taxon_name][:data].push(specimen)
        else
            specimens_of_taxon[taxon_name][:nomial]                 = nomial
            specimens_of_taxon[taxon_name][:first_specimen_info]    = first_specimen_info
            specimens_of_taxon[taxon_name][:data]                   = [specimen]
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
        ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'class_name', 'phylum_name']
    end
end