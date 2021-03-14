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

    def self.taxa_names_for_rank(taxon: , rank:)

        ranked_lineages = NcbiRankedLineage.where(regnum: taxon.regnum, phylum: taxon.phylum, classis: taxon.classis, ordo: taxon.ordo, familia: taxon.familia, genus: taxon.genus, species: "").where.not("name LIKE ? OR name LIKE ? OR name LIKE ? OR name LIKE ?", '%sp.%', '%unclassified%', '%environmental%', '%uncultured%')

        ranked_lineages_for_rank = ranked_lineages.select do |ranked_lineage|
            ncbi_node_record = NcbiNode.find_by(tax_id: ranked_lineage.tax_id)
            if ncbi_node_record
                ncbi_node_record.rank == rank
            else
                false
            end
        end

        taxa_names = []
        ranked_lineages_for_rank.each { |tax| taxa_names.push([Helper.choose_ncbi_record(tax.name), tax.name]) }
    
        return taxa_names
    end
end
