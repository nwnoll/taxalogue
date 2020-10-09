# frozen_String_literal: true

class Lineage
      attr_accessor :kingdom, :phylum, :classis, :ordo, :familia, :genus, :species, :sub_species, :name, :combined, :rank

      def initialize(kingdom: nil, phylum: nil, classis: nil, ordo: nil, familia: nil, genus: nil, species: nil, sub_species: nil, name: nil, combined: nil, rank: nil)
            @kingdom          = kingdom
            @phylum           = phylum
            @classis          = classis
            @ordo             = ordo
            @familia          = familia
            @genus            = genus
            @species          = species
            @sub_species      = sub_species

            @name             = name
            @combined         = combined
            @rank             = Helper.latinize_rank(rank)

            self.send "#{rank}=", name if self.respond_to?(rank.to_s)
      end
end