# frozen_string_literal: true

class GbifTaxonomy < ActiveRecord::Base
  self.table_name = 'gbif_taxonomy'

  def self.possible_ranks
    ['species', 'genus', 'family', 'order', 'class', 'phylum', 'kingdom']
  end

  def self.rank_mappings
    {
      'species' => 'species',
      'genus'   => 'genus',
      'family'   => 'familia',
      'order'   => 'ordo',
      'class'   => 'classis',
      'phylum'   => 'phylum',
      'kingdom'   => 'regnum',
    }
  end

  def self.taxa_names(taxon)
    taxa_names = []
    if taxon.taxon_rank == 'genus'
      taxa  = GbifTaxonomy.where(taxon_rank: 'species', genus: taxon.genus)
    elsif taxon.taxon_rank == 'family'
      taxa  = GbifTaxonomy.where(taxon_rank: 'genus', familia: taxon.familia)
    elsif taxon.taxon_rank == 'order'
      taxa  = GbifTaxonomy.where(taxon_rank: 'famliy', ordo: taxon.ordo)
    elsif taxon.taxon_rank == 'class'
      taxa  = GbifTaxonomy.where(taxon_rank: 'order', classis: taxon.classis)
    elsif taxon.taxon_rank == 'phylum'
      taxa  = GbifTaxonomy.where(taxon_rank: 'order', phylum: taxon.phylum)
    elsif taxon.taxon_rank == 'kingdom'
      taxa  = GbifTaxonomy.where(taxon_rank: 'order', regnum: taxon.regnum)
    else
      taxa = [taxon.canonical_name]
    end

    taxa.each { |tax| taxa_names.push(tax.canonical_name) }

    return taxa_names
  end

  def self.taxa_names_for_rank(taxon:, rank:)
    next_higher_rank            = GbifTaxonomy.next_higher_rank(rank: rank)
    return nil if next_higher_rank.nil?
    latinized_next_higher_rank  = Helper.latinize_rank(next_higher_rank)
    # byebug if latinized_next_higher_rank.nil?
    taxa                        = GbifTaxonomy.where(taxonomic_status: 'accepted', taxon_rank: rank, latinized_next_higher_rank => taxon.public_send(latinized_next_higher_rank))
    taxa_names                  = []
    taxa.each { |tax| taxa_names.push([tax, tax.canonical_name]) }

    return taxa_names
  end

  def self.next_higher_rank(rank:)
    index_of_rank               = GbifTaxonomy.possible_ranks.index(rank)
    index_of_higher_rank        = index_of_rank + 1
    return nil if index_of_rank ==  GbifTaxonomy.possible_ranks.size
    GbifTaxonomy.possible_ranks[index_of_higher_rank]
  end

  def self.names_for(rank)
    name_records = GbifTaxonomy.where(taxon_rank: rank)
    return [] if name_records.empty?
    names = []
    name_records.map { |r| names.push(r.canonical_name) }
    return names
  end

  private
  # def self._higher_than_order(taxon)
  #   ['kingdom', 'phylum', 'class'].include?(taxon.taxon_rank) if taxon
  # end
end
