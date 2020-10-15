# frozen_string_literal: true

module TaxonSearch
  private
  def _ncbi_next_highest_taxa_name(taxon_name)
    ncbi_ranked_lineage_object    = NcbiRankedLineage.find_by_name(taxon_name)
    return unless ncbi_ranked_lineage_object

    ncbi_node_with_possible_rank  = _go_through_ranks(ncbi_ranked_lineage_object.tax_id)
    return unless ncbi_node_with_possible_rank

    ncbi_ranked_lineage_object    =  NcbiRankedLineage.find_by_tax_id(ncbi_node_with_possible_rank.tax_id)
    return unless ncbi_ranked_lineage_object

    return ncbi_ranked_lineage_object.name
  end

  def _go_through_ranks(tax_id)
    ncbi_node_object = NcbiNode.find_by_tax_id(tax_id)
    return unless ncbi_node_object

    loop do
      return ncbi_node_object if GbifTaxon.possible_ranks.include?(ncbi_node_object.rank)

      ncbi_node_object = NcbiNode.find_by_tax_id(ncbi_node_object.parent_tax_id)
      return nil unless ncbi_node_object
      return nil if ncbi_node_object.parent_tax_id == ncbi_node_object.tax_id
    end
  end
end
