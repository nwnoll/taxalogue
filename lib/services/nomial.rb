# frozen_string_literal: true

class Nomial
  attr_reader :name, :query_taxon, :query_taxon_rank

  def initialize(name:, query_taxon:, query_taxon_rank:)
    @name                     = name
    @query_taxon              = query_taxon
    @query_taxon_rank         = query_taxon_rank
  end

  def self.generate(name:, query_taxon:, query_taxon_rank:)
    new(name: name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank).generate
  end

  def generate
    return Monomial.new(name: _cleaned_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)    if _cleaned_name_parts.size == 1
    return Polynomial.new(name: _cleaned_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)  if _cleaned_name_parts.size > 1
    return self
  end

  def taxonomy
    nil
  end

  private
  def _name_parts
    name.split
  end

  def _open_nomenclature
    ['gen.', 'sp.', 'ssp.', 'var.', 'subvar.', 'f.', 'subf.', 'cf.', 'kl.', 'nr.', 'aff.']
  end

  def _cleaned_name_parts
    i                   = _open_nomenclature.map { |n| _name_parts.index(n) }.compact.min
    cleaned_name_parts  = _name_parts[0 ... i]
  end

  def _cleaned_name
    cleaned_name = _cleaned_name_parts.join(' ')
  end
end

class Monomial
  require_relative 'string_formatting'
  include TaxonSearch
  include StringFormatting

  attr_reader :name, :query_taxon, :query_taxon_rank
  def initialize(name:, query_taxon:, query_taxon_rank:)
    @name               = name
    @query_taxon  = query_taxon
    @query_taxon_rank  = query_taxon_rank
  end

  def taxonomy
    record = _gbif_taxon_object(name, query_taxon, query_taxon_rank)
    return record    unless record.nil?

    record = _gbif_taxon_object(_ncbi_next_highest_taxa_name(name), query_taxon, query_taxon_rank)
    return record    unless record.nil?

    exact_gbif_api_match =   _exact_gbif_api_result(name)
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?
  end

  private
  def _gbif_taxon_object(taxon_name, higher_taxon, query_taxon_rank)
    return nil if taxon_name.nil? || higher_taxon.nil? || query_taxon_rank.nil?
    records = GbifTaxon.where(canonical_name: taxon_name)

    ## what to do if there are only synonyms?
    records.each do |record|
      if record.taxonomic_status == 'accepted'
        return record if _has_lineage?(record)
      end
    end
    return nil
  end

  def _has_lineage?(record)
    !record.phylum.nil? && !record.classis.nil? if record
  end

  def _record_exists?(taxon_name)
    taxon_name && GbifTaxon.exists?(canonical_name: taxon_name)
  end

  def _exact_gbif_api_result(taxon_name)
    GbifApi.new(query: taxon_name).exact_match
  end

  def _fuzzy_gbif_api_result(taxon_name)
    GbifApi.new(path: 'species/match?strict=true&name=', query: taxon_name).fuzzy_match
  end

end

class Polynomial < Monomial
  def taxonomy
    record = _gbif_taxon_object(name, query_taxon, query_taxon_rank)
    return record    unless record.nil?

    exact_gbif_api_match =   _exact_gbif_api_result(name)
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?

    record = _gbif_taxon_object(_ncbi_next_highest_taxa_name(name), query_taxon, query_taxon_rank)
    return record    unless record.nil?

    cutted_name = _remove_last_name_part(name)
    return nil if cutted_name.blank?
    nomial = Nomial.generate(name: cutted_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
    nomial.taxonomy
  end

  private
  def _remove_last_name_part(name_to_clean)
    parts = name_to_clean.split(' ')
    parts.pop
    parts = parts.join(' ')
    return parts
  end
end
