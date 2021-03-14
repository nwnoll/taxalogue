# frozen_string_literal: true

class NcbiTaxonomy
    def self.ranks_for_combined
        ['family', 'order', 'class', 'phylum', 'kingdom']
    end

    def self.possible_ranks
        ['species', 'genus', 'family', 'order', 'class', 'phylum', 'kingdom']
    end

    # Proxy for ActiveRecord method redirects to AR class
    def self.where(tax_id:)
        ncbi_names = NcbiName.where(tax_id: tax_id)
        synonyms = ncbi_names.select { |record| record.name_class == 'synonym' || record.name_class == 'includes' }
        return synonyms
    end

    def self.taxa_names_for_rank(taxon:, rank:)
        next_higher_rank            = next_higher_rank(rank: rank)
        return nil if next_higher_rank.nil?
        latinized_next_higher_rank  = Helper.latinize_rank(next_higher_rank)
        # byebug if latinized_next_higher_rank.nil?
        taxa                        = GbifTaxonomy.where(taxonomic_status: 'accepted', taxon_rank: rank, latinized_next_higher_rank => taxon.public_send(latinized_next_higher_rank))
        taxa_names                  = []
        taxa.each { |tax| taxa_names.push([tax, tax.canonical_name]) }
    
        return taxa_names
      end
    
      def self.next_higher_rank(rank:)
        index_of_rank               = possible_ranks.index(rank)
        index_of_higher_rank        = index_of_rank + 1
        return nil if index_of_rank ==  possible_ranks.size
        possible_ranks[index_of_higher_rank]
      end
end
