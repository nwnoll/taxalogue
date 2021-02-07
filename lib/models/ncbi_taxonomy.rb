# frozen_string_literal: true

class NcbiTaxonomy
    def self.ranks_for_combined
        ['family', 'order', 'class', 'phylum', 'kingdom']
    end

    def self.allowed_ranks
        ['species', 'genus', 'family', 'order', 'class', 'phylum', 'kingdom']
    end
end
