# frozen_string_literal: true

class GbifTaxon < ActiveRecord::Base
  self.table_name = 'gbif_taxa'

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

  def self.taxa_names(taxon_name)
    taxa_names = []
    if _higher_than_order(taxon_name)
      taxon = GbifTaxon.find_by_canonical_name(taxon_name)
      if taxon.taxon_rank == 'class'
        taxa  = GbifTaxon.where(taxon_rank: 'order', classis: taxon.classis)
      elsif taxon.taxon_rank == 'phylum'
        taxa  = GbifTaxon.where(taxon_rank: 'order', phylum: taxon.phylum)
      elsif taxon.taxon_rank == 'kingdom'
        taxa  = GbifTaxon.where(taxon_rank: 'order', regnum: taxon.regnum)
      end

      taxa.each { |tax| taxa_names.push(tax.canonical_name) }

      return taxa_names
    else
      taxa_names.push(taxon_name)

      return taxa_names
    end
  end

  def self.names_for(rank)
    name_records = GbifTaxon.where(taxon_rank: rank)
    return [] if name_records.empty?
    names = []
    name_records.map { |r| names.push(r.canonical_name) }
    return names
  end

  private
  def self._higher_than_order(taxon_name)
    taxon = GbifTaxon.find_by_canonical_name(taxon_name)
    ['kingdom', 'phylum', 'class'].include?(taxon.taxon_rank) if taxon
  end
end
