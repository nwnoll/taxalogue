# frozen_String_literal: true

class Lineage
      attr_writer :regnum, :phylum, :classis, :ordo, :familia, :genus, :species, :name, :combined, :rank

      def initialize(regnum:, phylum:, classis:, ordo:, familia:, genus:, species:, name:, combined:, rank:)
            @regnum     = regnum
            @phylum     = phylum
            @classis    = classis
            @ordo       = ordo
            @familia    = familia
            @genus      = genus
            @species    = species
            @name       = name
            @combined   = combined
            @rank       = Helper.latinize_rank(rank)
            
            self.send "#{rank}=", name
      end
end