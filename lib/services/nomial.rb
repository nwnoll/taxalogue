# frozen_string_literal: true

class Nomial
  attr_reader :name, :query_taxon_object, :query_taxon_rank, :cleaned_name_parts, :cleaned_name, :taxonomy_params

  def initialize(name:, query_taxon_object:, query_taxon_rank:, taxonomy_params:)
    @name                     = name
    @query_taxon_object       = query_taxon_object
    @query_taxon_rank         = query_taxon_rank
    @cleaned_name_parts       = _cleaned_name_parts
    @cleaned_name             = _cleaned_name
    @taxonomy_params          = taxonomy_params
  end

  def self.generate(name:, query_taxon_object:, query_taxon_rank:, taxonomy_params:)
    new(name: name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params).generate
  end

  def generate
    return Monomial.new(name: cleaned_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)    if cleaned_name_parts.size == 1
    return Polynomial.new(name: cleaned_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)  if cleaned_name_parts.size > 1
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
  require_relative 'taxon_search'
  include TaxonSearch
  include StringFormatting

  attr_reader :name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :taxonomy_params
  def initialize(name:, query_taxon_object:, query_taxon_rank:, taxonomy_params:)
    @name                 = name
    @query_taxon_object   = query_taxon_object
    @query_taxon_name     = query_taxon_object.canonical_name
    @query_taxon_rank     = query_taxon_rank
    @taxonomy_params      = taxonomy_params
  end

  def taxonomy(first_specimen_info:, importer:)
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?
    
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_exact: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_fuzzy: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?
  end

  def gbif_taxonomy(first_specimen_info:, importer:)
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?
    
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_exact: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_fuzzy: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?
  end

  def gbif_taxonomy_backbone(first_specimen_info:, importer:)
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?
  end

  def ncbi_taxonomy(first_specimen_info:, importer:)
    records = _get_ncbi_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _ncbi_taxonomy_object(records: records)
    return record unless record.nil?

  end

  private
  def _gbif_taxonomy_object(records:)
    return nil if records.nil? || records.empty?

    accepted_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_accepted?(record) }
    return accepted_records.first if accepted_records.size > 0

    doubtful_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_doubtful?(record) }
    return doubtful_records.first if doubtful_records.size > 0

    if are_synonyms_allowed
      synonymous_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_synonym?(record) }
      return synonymous_records.first if synonymous_records.size > 0
    else
      synonymous_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && _is_synonym?(record) && _has_accepted_name_usage_id(record) }
      return GbifTaxonomy.find_by(taxon_id: synonymous_records.first.accepted_name_usage_id.to_i) if synonymous_records.size > 0
    end

    return nil
  end

  def _ncbi_taxonomy_object(records:)
    return nil if records.nil? || records.empty?

    scientific_name_records = records.select do |record|
      _belongs_to_correct_query_taxon_rank?(record) && has_scientific_name_in_ncbi?(record) 
    end
    return scientific_name_records.first if scientific_name_records.size > 0


    synonym_records = records.select do |record|
      _belongs_to_correct_query_taxon_rank?(record) && has_scientific_name_in_ncbi?(record) 
    end

    # synonym_records = records.select do |record| 
    #   ncbi_ranked_lineage_record = NcbiRankedLineage.find_by(tax_id: record.tax_id)
    #   _belongs_to_correct_query_taxon_rank?(ncbi_ranked_lineage_record) && is_synonym_in_ncbi?(record) 
    # end
    
    # authority_records = records.select do |record| 
    #   _belongs_to_correct_query_taxon_rank?(record) && is_authority_in_ncbi?(record) }
    
    # synonym_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && is_synonym_in_ncbi?(record) }
    
    # includes_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record) && is_includes_in_ncbi?(record) }


    # scientific_name_records = records.select {  }
    # authority_records
    # synonym_records
    # includes_records
    # in_part_records

    ## NEXT
    # if i want to use _belongs_to_correct_query_taxon_rank than i need the NcbiRankedLineage
    # what is here the best way?
    # ask for if tere are any scientif names
    # if not search for synonym names and maybe for includes or in-part names
    # 
    return scientific_name_records.first

  end

  def _get_records(current_name:, importer:, first_specimen_info:, gbif_api_exact: false, gbif_api_fuzzy: false)
    return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    all_records = GbifTaxonomy.where(canonical_name: current_name)            if !gbif_api_exact  && !gbif_api_fuzzy
    all_records = GbifApi.new(query: current_name).records                    if gbif_api_exact   && !gbif_api_fuzzy
    all_records = GbifApi.new(path: _fuzzy_path, query: current_name).records if gbif_api_fuzzy   && !gbif_api_exact
    return nil if all_records.nil?

    records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: all_records) : all_records

    return records
  end

  def _get_gbif_records(current_name:, importer:, first_specimen_info:, gbif_api_exact: false, gbif_api_fuzzy: false)
    return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    all_records = GbifTaxonomy.where(canonical_name: current_name)            if !gbif_api_exact  && !gbif_api_fuzzy
    all_records = GbifApi.new(query: current_name).records                    if gbif_api_exact   && !gbif_api_fuzzy
    all_records = GbifApi.new(path: _fuzzy_path, query: current_name).records if gbif_api_fuzzy   && !gbif_api_exact
    return nil if all_records.nil?

    records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: all_records) : all_records

    return records
  end

  def _get_ncbi_records(current_name:, importer:, first_specimen_info:)
    return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    all_records = NcbiName.where(name: current_name)
    return nil if all_records.nil?

    ncbi_taxonomy_objects = []
    all_records.each do |record|
      ncbi_ranked_lineage_record = NcbiRankedLineage.find_by(tax_id: record.tax_id)
      ncbi_node_record           = NcbiNode.find_by(tax_id: record.tax_id)

      ## NEXT
      # Problem here is that taxon_id points to the scientific name taxon_id
      # and not to the synonym taxon_id there is no tax_id for the synonym
      # same problem with the whole lineage...
      # if synonyms are allowed i could maybe go through all ranks?
      # but most probably they will have the same genus etc info...
      # this might not work, other thing would be to ignore, if its a homonym
      # and synonms are allowed than ignore genus?
      obj = OpenStruct.new(
        taxon_id:               record.tax_id,
        regnum:                 ncbi_ranked_lineage_record.regnum,
        phylum:                 ncbi_ranked_lineage_record.phylum,
        classis:                ncbi_ranked_lineage_record.classis,
        ordo:                   ncbi_ranked_lineage_record.ordo,
        familia:                ncbi_ranked_lineage_record.familia,
        genus:                  ncbi_ranked_lineage_record.genus,
        canonical_name:         ncbi_ranked_lineage_record.name,
        scientific_name:        'blank_sciname',
        taxonomic_status:       record.name_class,
        taxon_rank:             ncbi_node_record.rank,
        combined:               'blank_combined',
        comment:                'blank_comment'
      )

      ncbi_taxonomy_objects.push(obj)
    end


    pp ncbi_taxonomy_objects


    ## TODO: NcbIname record does not have taxon rank so maybe i need to 
    ## get NcbiNode and NcbiRankedLineage beforehand??
    records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: ncbi_taxonomy_objects) : ncbi_taxonomy_objects
    # records = all_records

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

  def has_scientific_name_in_ncbi?(record)
    record.taxonomic_status =~ /scientific name/
  end

  def is_authority_in_ncbi?(record)
    record.taxonomic_status =~ /authority/
  end

  def is_synonym_in_ncbi?(record)
    record.taxonomic_status =~ /synonym/
  end

  def is_includes_in_ncbi?(record)
    record.taxonomic_status =~ /includes/
  end

  def is_in_part_in_ncbi?(record)
    record.taxonomic_status =~ /in-part/
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
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    parsed = Biodiversity::Parser.parse(name)
    if parsed[:parsed]
      name_stem = parsed[:canonical][:stemmed]
      records = _get_records(current_name: name_stem, importer: importer, first_specimen_info: first_specimen_info)
      record  = _gbif_taxonomy_object(records: records)

      return record unless record.nil?
    end
    
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_exact: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_fuzzy: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    cutted_name = _remove_last_name_part(name)
    return nil if cutted_name.blank?
    nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)
    nomial.taxonomy(first_specimen_info: first_specimen_info, importer: importer)
  end

  def gbif_taxonomy(first_specimen_info:, importer:)
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    parsed = Biodiversity::Parser.parse(name)
    if parsed[:parsed]
      name_stem = parsed[:canonical][:stemmed]
      records = _get_records(current_name: name_stem, importer: importer, first_specimen_info: first_specimen_info)
      record  = _gbif_taxonomy_object(records: records)

      return record unless record.nil?
    end
    
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_exact: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info, gbif_api_fuzzy: true)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    cutted_name = _remove_last_name_part(name)
    return nil if cutted_name.blank?
    nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)
    nomial.gbif_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
  end


  def gbif_taxonomy_backbone(first_specimen_info:, importer:)
    records = _get_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    parsed = Biodiversity::Parser.parse(name)
    if parsed[:parsed]
      name_stem = parsed[:canonical][:stemmed]
      records = _get_records(current_name: name_stem, importer: importer, first_specimen_info: first_specimen_info)
      record  = _gbif_taxonomy_object(records: records)

      return record unless record.nil?
    end

    records = _get_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    cutted_name = _remove_last_name_part(name)
    return nil if cutted_name.blank?
    nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)
    nomial.gbif_taxonomy_backbone(first_specimen_info: first_specimen_info, importer: importer)
  end






  private
  def _remove_last_name_part(name_to_clean)
    parts = name_to_clean.split(' ')
    parts.pop
    parts = parts.join(' ')
    return parts
  end
end
