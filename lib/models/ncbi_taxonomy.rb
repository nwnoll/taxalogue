# frozen_string_literal: true

class NcbiTaxonomy
    def self.ranks_for_combined
        ['family', 'order', 'class', 'phylum', 'kingdom']
    end

    def self.allowed_ranks
        ['species', 'genus', 'family', 'order', 'class', 'phylum', 'kingdom']
    end

    # Proxy for ActiveRecord method redirects to AR class
    def self.where(tax_id:)
        ncbi_names = NcbiName.where(tax_id: tax_id)
        synonyms = ncbi_names.select { |record| record.name_class == 'synonym' || record.name_class == 'includes' }
        return synonyms
    end
end
