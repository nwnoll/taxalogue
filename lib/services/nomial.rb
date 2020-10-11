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

  def taxonomy(first_specimen_info:, importer:)
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

  def taxonomy(first_specimen_info:, importer:)
    # if GbifHomonomy.exists?(canonical_name: name)
    _check_for_homonyms(first_specimen_info: first_specimen_info, importer: importer)

    ## >
    record = _gbif_taxon_object(name, first_specimen_info)
    return record    unless record.nil?
    ## >
    record = _gbif_taxon_object(_ncbi_next_highest_taxa_name(name), first_specimen_info)
    return record    unless record.nil?
    
    exact_gbif_api_match =   _exact_gbif_api_result(name)
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?
  end

  private
  def _gbif_taxon_object(taxon_name, first_specimen_info)
    return nil if taxon_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    records = GbifTaxon.where(canonical_name: taxon_name)

    ## the problem is that i dont know now where to put the db request if it is a homonym
    ## it needs to be inside the nomial class beacuse a cutted name might be anouther homonym
    ## maybe should give it from the outside?
    ## 
    # implement homonyms.txt later on
    # if _is_homonym?(taxon_name)
    #   first_specimen_info
    # end
    records.each do |record|
      next unless _belongs_to_correct_query_taxon_rank?(record)
      return record if _is_accepted?(record) || _is_doubtful?(record)
      return GbifTaxon.find_by(taxon_id: record.accepted_name_usage_id.to_i) if _is_synonym?(record) && _has_accepted_name_usage_id(record)
    end

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

  def _is_homonym?(taxon_name)
    GbifHomonym.exists?(canonical_name: taxon_name)
  end

  def _has_accepted_name_usage_id(record)
    !record.accepted_name_usage_id.nil?
  end

  def _belongs_to_correct_query_taxon_rank?(record)
    record.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name
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

  def _check_for_homonyms(first_specimen_info:, importer:)
    if GbifHomonym.exists?(canonical_name: name)
      lineage = importer.get_lineage(first_specimen_info)
      _find_correct_taxon(current_name: name, lineage: lineage, importer: importer)
    end
  end

  def _find_correct_taxon(current_name:, lineage:, importer:)
    if importer == GbolImporter
      puts '*' * 100
      p current_name
      lineage.combined.reverse.each do |taxon|
        p "-- #{taxon}"
      end
      gbif_homonym = GbifHomonym.find_by(canonical_name: current_name)
      pp gbif_homonym
      gbif_taxon_objects = GbifTaxon.where(canonical_name: current_name)
      # gbif_taxon_objects.each { |o| pp o }
      puts '_unambiguous_classification?'
      p _unambiguous_classification?(current_name: current_name, lineage: lineage)
      puts '*' * 100
      sleep 2
    elsif importer == BoldImporter
      p 'shiish'
    end
  end

  def _unambiguous_classification?(current_name:, lineage:)
    gbif_homonym          = GbifHomonym.find_by(canonical_name: current_name)
    gbif_homonym_rank     = gbif_homonym.rank
    possible_ranks        = GbifTaxon.possible_ranks
    # gbif_taxon_rank_index = possible_ranks.index(gbif_homonym_rank)
    # next_higher_rank  = possible_ranks[(gbif_taxon_rank_index + 1)]

    gbif_taxon_objects    = GbifTaxon.where(canonical_name: current_name)
    gbif_taxon_objects.each do |taxon_object|
      # next_higher_rank  = possible_ranks[(gbif_taxon_rank_index + 1)]
      # latinized_rank    = Helper.latinize_rank(next_higher_rank)
      lineage.combined.reverse.each do |taxon|
        p "#{taxon_object.public_send('familia')} == #{taxon}" if taxon_object.public_send('familia')  == taxon
        return true if taxon_object.public_send('familia')  == taxon
        p "#{taxon_object.public_send('ordo')} == #{taxon}" if taxon_object.public_send('ordo')     == taxon
        return true if taxon_object.public_send('ordo')     == taxon
      end
    end
    
    return false
  end

end

class Polynomial < Monomial
  def taxonomy(first_specimen_info:, importer:)
    _check_for_homonyms(first_specimen_info: first_specimen_info, importer: importer)
    # if GbifHomonym.exists?(canonical_name: name)
    #   lineage = importer.get_lineage(first_specimen_info)
    #   _find_correct_taxon(current_name: name, lineage: lineage, importer: importer)
    # end
    
    record = _gbif_taxon_object(name, first_specimen_info)
    return record    unless record.nil?

    exact_gbif_api_match =   _exact_gbif_api_result(name)
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?
    ## >
    record = _gbif_taxon_object(_ncbi_next_highest_taxa_name(name), first_specimen_info)
    return record    unless record.nil?

    cutted_name = _remove_last_name_part(name)
    return nil if cutted_name.blank?
    nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)
    nomial.taxonomy(first_specimen_info: first_specimen_info, importer: importer)
  end

  private
  def _remove_last_name_part(name_to_clean)
    parts = name_to_clean.split(' ')
    parts.pop
    parts = parts.join(' ')
    return parts
  end
end
