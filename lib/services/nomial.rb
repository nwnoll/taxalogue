# frozen_string_literal: true

class Nomial
  attr_reader :name, :query_taxon_object, :query_taxon_rank, :cleaned_name_parts, :cleaned_name

  def initialize(name:, query_taxon_object:, query_taxon_rank:)
    @name                     = name
    @query_taxon_object       = query_taxon_object
    @query_taxon_rank         = query_taxon_rank
    @cleaned_name_parts       = _cleaned_name_parts
    @cleaned_name             = _cleaned_name
  end

  def self.generate(name:, query_taxon_object:, query_taxon_rank:)
    new(name: name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank).generate
  end

  def generate
    return Monomial.new(name: cleaned_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)    if cleaned_name_parts.size == 1
    return Polynomial.new(name: cleaned_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)  if cleaned_name_parts.size > 1
    return self
  end

  def taxonomy
    nil
  end

  private
  def _name_parts
    return nil unless name.kind_of?(String)
    name.split
  end

  def _open_nomenclature
    ['gen.', 'sp.', 'ssp.', 'var.', 'subvar.', 'f.', 'subf.', 'cf.', 'kl.', 'nr.', 'aff.']
  end

  def _cleaned_name_parts
    return [] if _name_parts.nil?
    i                   = _open_nomenclature.map { |n| _name_parts.index(n) }.compact.min
    cleaned_name_parts  = _name_parts[0 ... i]
    cleaned_name_parts.map! { |word| Helper.normalize(word) }
    cleaned = cleaned_name_parts.delete_if { |word| word =~ /[0-9]|_|\W/}
    if cleaned.size > 1

      # cleaned[1..-1]
      # cleaned.drop(1).delete_if { |word| word =~ /[A-Z]/ }
      cleaned.select! { |word| word == cleaned[0] || word !~ /[A-Z]/}
    end
    cleaned
  end

  def _cleaned_name
    cleaned_name = cleaned_name_parts.join(' ')
  end
end

class Monomial
  require_relative 'string_formatting'
  include TaxonSearch
  include StringFormatting

  attr_reader :name, :query_taxon_object, :query_taxon_rank, :query_taxon_name
  def initialize(name:, query_taxon_object:, query_taxon_rank:)
    @name               = name
    @query_taxon_object = query_taxon_object
    @query_taxon_name   = query_taxon_object.canonical_name
    @query_taxon_rank   = query_taxon_rank
  end

  def taxonomy
    record = _gbif_taxon_object(name, query_taxon_object, query_taxon_rank)
    return record    unless record.nil?

    record = _gbif_taxon_object(_ncbi_next_highest_taxa_name(name), query_taxon_object, query_taxon_rank)
    return record    unless record.nil?
    
    
    exact_gbif_api_match =   _exact_gbif_api_result(name)
    unless exact_gbif_api_match.nil?
      puts "exact_gbif_api_match"
      p name
      pp exact_gbif_api_match
      puts '---------'
    end
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    unless fuzzy_gbif_api_match.nil?
      puts "fuzzy_gbif_api_match"
      p name
      pp fuzzy_gbif_api_match
      puts '---------'
    end
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?
  end

  private
  def _gbif_taxon_object(taxon_name, higher_taxon_object, query_taxon_rank)
    return nil if taxon_name.nil? || higher_taxon_object.nil? || query_taxon_rank.nil?
    
    records = GbifTaxon.where(canonical_name: taxon_name)
    # implement homonyms.txt later on
    # byebug if name == 'Hanseniella'

    records.each do |record|
      next unless _belongs_to_correct_query_taxon_rank?(record)
      return record if _is_accepted?(record) || _is_doubtful?(record)
      return GbifTaxon.find_by(taxon_id: record.accepted_name_usage_id.to_i) if _is_synonym?(record) && _has_accepted_name_usage_id(record)
    end
    # puts "found nothing"
    # p  name
    # records.each { |r| pp r }
    # puts '+' * 100
    return nil
  end

  def _is_accepted?(record)
    record.taxonomic_status == 'accepted'
  end 
  
  def _is_doubtful?(record)
    record.taxonomic_status == 'doubtful'
  end

  def _is_synonym?(record)
    record.taxonomic_status =~ /synonym|misapplied/i
  end

  def _has_accepted_name_usage_id(record)
    !record.accepted_name_usage_id.nil?
  end

  def _belongs_to_correct_query_taxon_rank?(record)
    rank = record.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name


    ## migth implement a search function if there is lacking info for higher taxa

    # rank = record.public_send(Helper.latinize_rank(query_taxon_rank))
    # if rank.nil?
    #   ncbi_records = NcbiRankedLineage.where(name: record.canonical_name)
    #   ncbi_records.each do |ncbi_record|
    #     next unless ncbi_record.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name
    #     p 'in _belongs_to_correct_query_taxon_rank rank.nil?'
    #     p name
    #     p record
    #     p ncbi_record
    #     p '**************'
    #   end
    # else
    #   return rank == query_taxon_name
    # end
   
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
    record = _gbif_taxon_object(name, query_taxon_object, query_taxon_rank)
    return record    unless record.nil?

    exact_gbif_api_match =   _exact_gbif_api_result(name)
    unless exact_gbif_api_match.nil?
      puts "exact_gbif_api_match"
      p name
      pp exact_gbif_api_match
      puts '---------'
    end
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    unless fuzzy_gbif_api_match.nil?
      puts "fuzzy_gbif_api_match"
      p name
      pp fuzzy_gbif_api_match
      puts '---------'
    end
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?

    record = _gbif_taxon_object(_ncbi_next_highest_taxa_name(name), query_taxon_object, query_taxon_rank)
    unless record.nil?
      puts "_ncbi_next_highest_taxa_name"
      p name
      pp record
      puts '---------'
    end
    return record    unless record.nil?

    cutted_name = _remove_last_name_part(name)
    return nil if cutted_name.blank?
    nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)
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
