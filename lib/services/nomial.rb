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
    
    return name.split
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
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?
    
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_exact: true)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_fuzzy: true)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?
  end

  private
  def _gbif_taxon_object(records:)
    return nil if records.nil? || records.empty?

    accepted_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_accepted?(record) }
    return accepted_records.first if accepted_records.size > 0

    doubtful_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_doubtful?(record) }
    return doubtful_records.first if doubtful_records.size > 0

    synonymous_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_synonym?(record) && _has_accepted_name_usage_id(record) }
    return GbifTaxon.find_by(taxon_id: synonymous_records.first.accepted_name_usage_id.to_i) if synonymous_records.size > 0

    return nil
  end

  def _get_records(current_name:, importer:, first_specimen_info:, gbif_api_exact: false, gbif_api_fuzzy: false)
    return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    all_records = GbifTaxon.where(canonical_name: current_name)               if !gbif_api_exact  && !gbif_api_fuzzy
    all_records = GbifApi.new(query: current_name).records                    if gbif_api_exact   && !gbif_api_fuzzy
    all_records = GbifApi.new(path: _fuzzy_path, query: current_name).records if gbif_api_fuzzy   && !gbif_api_exact
    return nil if all_records.nil?

    records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: all_records) : all_records

    return records
  end

  def _is_accepted?(record)
    record.taxonomic_status =~ /accepted/
  end 
  
  def _is_doubtful?(record)
    record.taxonomic_status =~ /doubtful/i
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

  def _fuzzy_path
    'species/match?strict=true&name='
  end

  def _records_with_matching_lineage(current_name:, lineage:, all_records:)
    gbif_homonym              = GbifHomonym.find_by(canonical_name: current_name)
    gbif_homonym_rank         = gbif_homonym.rank
    species_ranks             = ["subspecies", "variety", "form", "subvariety", "species"]
    genus_ranks               = ["genus"]
    family_ranks              = ["infrafamily", "family", "superfamily"]
    order_ranks               = ["infraorder", "order", "superorder"]
    class_ranks               = ["infraclass", "class", "superclass"]

    potential_correct_records = []
    all_records.each do |taxon_object|
      lineage.combined.reverse.each do |taxon|
        if species_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('genus')   == taxon
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('familia') == taxon
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon
        elsif genus_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('familia') == taxon
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon
        elsif family_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon
        elsif order_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('classis') == taxon
        elsif class_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('phylum')  == taxon
        end
      end
    end

    return potential_correct_records
  end
end

class Polynomial < Monomial
  def taxonomy(first_specimen_info:, importer:)
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?
    
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_exact: true)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_fuzzy: true)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxon_object(records: records)
    return record unless record.nil?

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
