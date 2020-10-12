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
    cleaned.select! { |word| word == cleaned[0] || word !~ /[A-Z]/} if cleaned.size > 1
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
    record = _gbif_taxon_object(taxon_name: name, importer: importer, first_specimen_info: first_specimen_info)
    return record    unless record.nil?

    record = _gbif_taxon_object(taxon_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    return record    unless record.nil?
    
    exact_gbif_api_match =   _exact_gbif_api_result(name)
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?
  end

  private
  def _gbif_taxon_object(taxon_name:, importer:, first_specimen_info:)
    return nil if taxon_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    if _is_homonym?(taxon_name)
      lineage = importer.get_lineage(first_specimen_info)
      records = _records_with_matching_lineage(current_name: taxon_name, lineage: lineage)
    else
      records = GbifTaxon.where(canonical_name: taxon_name)
    end

    accepted_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_accepted?(record) }
    return accepted_records.first if accepted_records.size > 0

    doubtful_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_doubtful?(record) }
    return accepted_records.first if accepted_records.size > 0

    synonymous_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_synonym?(record) && _has_accepted_name_usage_id(record) }
    return GbifTaxon.find_by(taxon_id: synonymous_records.first.accepted_name_usage_id.to_i) if synonymous_records.size > 0

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

  def _records_with_matching_lineage(current_name:, lineage:)
    gbif_homonym              = GbifHomonym.find_by(canonical_name: current_name)
    gbif_homonym_rank         = gbif_homonym.rank
    species_ranks             = ["subspecies", "variety", "form", "subvariety", "species"]
    genus_ranks               = ["genus"]
    family_ranks              = ["infrafamily", "family", "superfamily"]
    order_ranks               = ["infraorder", "order", "superorder"]
    class_ranks               = ["infraclass", "class", "superclass"]

    gbif_taxon_objects    = GbifTaxon.where(canonical_name: current_name)
    potential_correct_records = []
    gbif_taxon_objects.each do |taxon_object|
      lineage.combined.reverse.each do |taxon|
        if species_ranks.include? taxon_object.taxon_rank
          if taxon_object.public_send('genus')    == taxon
            # p '-- species genus'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break
          elsif taxon_object.public_send('familia')  == taxon
            # p '-- species familia'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break
          elsif taxon_object.public_send('ordo')     == taxon
            # p '-- species ordo'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break
          end
        elsif genus_ranks.include? taxon_object.taxon_rank
          if taxon_object.public_send('familia')  == taxon
            # p '-- genus familia'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break 
          elsif taxon_object.public_send('ordo')     == taxon
            # p '-- genus ordo'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break 
          end
        elsif family_ranks.include? taxon_object.taxon_rank
          if taxon_object.public_send('ordo')     == taxon
            # p '-- family ordo'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break
          end
        elsif order_ranks.include? taxon_object.taxon_rank
          if taxon_object.public_send('classis')  == taxon
            # p '-- ordo classis'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break
          end
        elsif class_ranks.include? taxon_object.taxon_rank
          if taxon_object.public_send('phylum')   == taxon
            # p '-- classis phylum'
            # pp taxon_object
            potential_correct_records.push(taxon_object)
            break
          end
        end
      end
    end

    # puts '*' * 100
    # pp potential_correct_records
    # puts '*' * 100
    return potential_correct_records
  end
end

class Polynomial < Monomial
  def taxonomy(first_specimen_info:, importer:)
    record = _gbif_taxon_object(taxon_name: name, importer: importer, first_specimen_info: first_specimen_info)
    return record unless record.nil?

    exact_gbif_api_match =   _exact_gbif_api_result(name)
    return exact_gbif_api_match   unless exact_gbif_api_match.nil?

    fuzzy_gbif_api_match = _fuzzy_gbif_api_result(name)
    return fuzzy_gbif_api_match   unless fuzzy_gbif_api_match.nil?

    record = _gbif_taxon_object(taxon_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
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
