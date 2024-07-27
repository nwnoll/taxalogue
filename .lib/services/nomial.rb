# frozen_string_literal: true

class Nomial
    attr_reader :name, :query_taxon_object, :query_taxon_rank, :cleaned_name_parts, :cleaned_name, :taxonomy_params, :are_synonyms_allowed

    def initialize(name:, query_taxon_object:, query_taxon_rank:, taxonomy_params:)
        @name                     = name
        @query_taxon_object       = query_taxon_object
        @query_taxon_rank         = query_taxon_rank
        @cleaned_name_parts       = _cleaned_name_parts
        @cleaned_name             = _cleaned_name
        @taxonomy_params          = taxonomy_params
        @are_synonyms_allowed     = taxonomy_params[:synonyms_allowed]
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
        return nil
    end

    private
    def _name_parts
        return nil unless name.kind_of?(String)
        
        return name.split
    end

    def _open_nomenclature
        ['gen.', 'sp.', 'sp', 'ssp.', 'var.', 'subvar.', 'f.', 'subf.', 'cf.', 'kl.', 'nr.', 'aff.']
    end

    def _cleaned_name_parts
        return [] if _name_parts.nil?

        i                   = _open_nomenclature.map { |n| _name_parts.index(n) }.compact.min
        cleaned_name_parts  = _name_parts[0 ... i]
        cleaned_name_parts.map! { |word| MiscHelper.normalize(word) }
        cleaned = cleaned_name_parts.delete_if { |word| word =~ /[0-9]|_|\W/}
        cleaned.select! { |word| word == cleaned[0] || word !~ /[A-Z]/} if cleaned.size > 1
        
        return cleaned
    end

    def _cleaned_name
        return cleaned_name_parts.join(' ')
    end
end

class Monomial
    require_relative 'string_formatting'
    include StringFormatting

    attr_reader :name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :taxonomy_params, :are_synonyms_allowed
    def initialize(name:, query_taxon_object:, query_taxon_rank:, taxonomy_params:)
        @name                 = name
        @query_taxon_object   = query_taxon_object
        @query_taxon_name     = query_taxon_object.canonical_name
        @query_taxon_rank     = query_taxon_rank
        @taxonomy_params      = taxonomy_params
        @are_synonyms_allowed = taxonomy_params[:synonyms_allowed]
    end

    def taxonomy(first_specimen_info:, importer:)
        if taxonomy_params[:gbif]
            record = gbif_taxonomy_backbone(first_specimen_info: first_specimen_info, importer: importer)
            return record

        elsif taxonomy_params[:ncbi]
            record = ncbi_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
            return record

        elsif taxonomy_params[:unmapped]
            record = unmapped_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
            return record
        else 
            ## default is ncbi_taxonomy
            record = ncbi_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
            return record
        end
    end

    def gbif_taxonomy_backbone(first_specimen_info:, importer:)

        records = _get_gbif_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
        record  = _gbif_taxonomy_object(records: records)
        return record unless record.nil?

        records = _get_gbif_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
        record  = _gbif_taxonomy_object(records: records)
        return record unless record.nil?

        source_lineage = importer.get_source_lineage(first_specimen_info)
        source_lineage.combined.reverse.each do |source_lineage_taxon_name|


            records = _get_gbif_records(current_name: source_lineage_taxon_name, importer: importer, first_specimen_info: first_specimen_info)
            record  = _gbif_taxonomy_object(records: records)
            return record unless record.nil?
        end

        return nil
    end

    def ncbi_taxonomy(first_specimen_info:, importer:)
        records = _get_ncbi_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
        record  = _ncbi_taxonomy_object(records: records)
        return record unless record.nil?
        
        records = _get_ncbi_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
        record  = _ncbi_taxonomy_object(records: records)
        return record unless record.nil?

        if self.class == Polynomial # otherwise there would be nothing to cut...
            cutted_name = _remove_last_name_part(name)
            return nil if cutted_name.blank?
            
            nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)
            nomial.ncbi_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
        end

        ## if there were no results it should go through the lineage from the source db entry
        ## and check if it can find an entry in the taxonomy db
        source_lineage = importer.get_source_lineage(first_specimen_info)
        source_lineage.combined.reverse.each do |source_lineage_taxon_name|
            records = _get_ncbi_records(current_name: source_lineage_taxon_name, importer: importer, first_specimen_info: first_specimen_info)
            record  = _ncbi_taxonomy_object(records: records)
            return record unless record.nil?
        end

        return nil
    end

    def unmapped_taxonomy(first_specimen_info:, importer:)
        obj = importer.get_taxon_object_for_unmapped(first_specimen_info)
        return nil if obj.nil?
        
        parsed = Biodiversity::Parser.parse(obj.canonical_name)
        if parsed[:parsed]
            name_full = parsed[:canonical][:full]
            

            if obj.taxon_rank.match?('species')
                obj.canonical_name = name_full
                obj.taxon_rank = 'genus' unless name_full.match?(' ')
            else
                latinized_taxon_rank        = TaxonomyHelper.latinize_rank(obj.taxon_rank)
                
                obj.canonical_name = name_full
                if latinized_taxon_rank.nil?
                    nil
                else
                    obj[latinized_taxon_rank] = name_full
                end
            end
        end

        return obj
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

        records = records.select { |record| NcbiTaxonomy.possible_ranks.include?(record.taxon_rank) }

        return records.first
    end

    def _get_gbif_records(current_name:, importer:, first_specimen_info:)
        return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
        
        all_records = GbifTaxonomy.where(canonical_name: current_name)
        return nil if all_records.nil?

        records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: all_records) : all_records

        return records
    end


    def _get_ncbi_records(current_name:, importer:, first_specimen_info:)
        return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?

        ncbi_name_records         = NcbiName.where(name: current_name)
        usable_ncbi_name_records  = ncbi_name_records.select { |record| record.name_class == 'scientific name' || record.name_class == 'synonym' || record.name_class == 'includes' || record.name_class == 'authority' } # || record.name_class == 'in-part'  }
        return nil if usable_ncbi_name_records.empty?
        
        ncbi_taxonomy_objects = []

        usable_ncbi_name_records.each do |usable_ncbi_name_record|
            ncbi_tax_id = usable_ncbi_name_record.tax_id
            ncbi_name_records_for_tax_id = NcbiName.where(tax_id: ncbi_tax_id)
            next if ncbi_name_records_for_tax_id.empty?

            ncbi_ranked_lineage_record = NcbiRankedLineage.find_by(tax_id: ncbi_tax_id)
            next unless _belongs_to_correct_query_taxon_rank?(ncbi_ranked_lineage_record)

            ncbi_node_record = NcbiNode.find_by(tax_id: ncbi_tax_id)
            next if ncbi_node_record.nil?

            authority         = nil
            canonical_name    = nil
            genus             = nil
            taxonomic_status  = nil
            familia           = ncbi_node_record.rank == 'family'   ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.familia
            ordo              = ncbi_node_record.rank == 'order'    ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.ordo
            classis           = ncbi_node_record.rank == 'class'    ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.classis
            phylum            = ncbi_node_record.rank == 'phylum'   ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.phylum
            regnum            = ncbi_node_record.rank == 'kingdom'  ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.regnum

            if are_synonyms_allowed
                scientifc_name_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'scientific name' }.first
                # canonical_name = scientifc_name_record.nil? ? usable_ncbi_name_record.name : scientifc_name_record.name 
                canonical_name = usable_ncbi_name_record.name 

                authority_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'authority' }.first
                authority = authority_record.nil? ? canonical_name : authority_record.name

                taxonomic_status = _taxonomic_status(usable_ncbi_name_record)

                if ncbi_node_record.rank == 'species' || ncbi_node_record.rank == 'subspecies' || ncbi_node_record.rank == 'genus' 
                    genus = usable_ncbi_name_record.name.split(' ')[0]
                end
            else
                scientifc_name_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'scientific name' }.first
                canonical_name = scientifc_name_record.name unless scientifc_name_record.nil?

                authority_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'authority' }.first
                authority = authority_record.nil? ? canonical_name : authority_record.name

                genus = ncbi_node_record.rank == 'genus' ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.genus

                taxonomic_status = _taxonomic_status(scientifc_name_record) unless scientifc_name_record.nil?
            end

            combined = _get_combined(ncbi_ranked_lineage_record, ncbi_node_record.rank)

            combined.push(genus)          if genus && !genus.empty?
            combined.push(canonical_name) unless combined.include?(canonical_name)

            obj = OpenStruct.new(
                taxon_id:               usable_ncbi_name_record.tax_id,
                regnum:                 regnum,
                phylum:                 phylum,
                classis:                classis,
                ordo:                   ordo,
                familia:                familia,
                genus:                  genus,
                canonical_name:         canonical_name,
                scientific_name:        authority,
                taxonomic_status:       taxonomic_status,
                taxon_rank:             ncbi_node_record.rank,
                combined:               combined,
                comment:                ''
            )

            ncbi_taxonomy_objects.push(obj)
        end
        
        if ncbi_taxonomy_objects.any?
            records = _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: ncbi_taxonomy_objects)
            return records
        else
            return []
        end
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
        if taxonomy_params[:gbif]
            record.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name
        elsif taxonomy_params[:unmapped]
            ## TODO:
            ## Problem with Hemiptera and GBOL
            record.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name
        else
            # ncbi

            ## NcbiRankedLineage does not have the canonical_name attribute
            ## therefore I need to use species
            if query_taxon_rank == "species"
                record.public_send("species") == query_taxon_name || record.name == query_taxon_name
            else
                record.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name || record.name == query_taxon_name
            end
        end
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
        species_ranks             = ["subspecies", "variety", "form", "subvariety", "species"]
        genus_ranks               = ["genus"]
        family_ranks              = ["infrafamily", "family", "superfamily", "subfamily"]
        order_ranks               = ["infraorder", "order", "superorder"]
        class_ranks               = ["infraclass", "class", "superclass"]
        potential_correct_records = []
        all_records.each do |taxon_object|
            lineage.combined.reverse.each do |taxon|
                if species_ranks.include? taxon_object.taxon_rank
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('genus')   == taxon
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('familia') == taxon
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon

                    if GbolClassifier::INCLUDED_TAXA['Hemiptera'].include?(taxon)
                        potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo') == 'Hemiptera'
                    end
                elsif genus_ranks.include? taxon_object.taxon_rank
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('familia') == taxon
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon

                    if GbolClassifier::INCLUDED_TAXA['Hemiptera'].include?(taxon)
                        potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo') == 'Hemiptera'
                    end
                elsif family_ranks.include? taxon_object.taxon_rank
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon

                    if GbolClassifier::INCLUDED_TAXA['Hemiptera'].include?(taxon)
                        potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo') == 'Hemiptera'
                    end
                elsif order_ranks.include? taxon_object.taxon_rank
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('classis') == taxon
                elsif class_ranks.include? taxon_object.taxon_rank
                    potential_correct_records.push(taxon_object) and break if taxon_object.public_send('phylum')  == taxon
                end
            end
        end
    
        return potential_correct_records
    end

   def _get_combined(record, rank_of_record)
       combined = []
       possible_ranks = NcbiTaxonomy.ranks_for_combined

       possible_ranks.reverse.each do |rank|
           rank_info = rank_of_record == rank ? record.name : record.public_send(TaxonomyHelper.latinize_rank(rank))
           combined.push(rank_info) unless rank_info.blank?
       end

       return combined
   end

    def _taxonomic_status(record)
        return if record.nil?

        if record.name_class == 'scientific name'
            return 'accepted'
        elsif record.name_class == 'synonym'
            return 'synonym'
        elsif record.name_class == 'includes'
            return 'synonym'
        elsif record.name_class == 'in-part' ## UNUSED atm
            return 'synonym'
        end
    end

   def _ncbi_next_highest_taxa_name(taxon_name)
       ncbi_ranked_lineage_object = NcbiRankedLineage.find_by_name(taxon_name)
       return unless ncbi_ranked_lineage_object

       ncbi_node_with_possible_rank = _go_through_ranks(ncbi_ranked_lineage_object.tax_id)
       return unless ncbi_node_with_possible_rank

       ncbi_ranked_lineage_object = NcbiRankedLineage.find_by_tax_id(ncbi_node_with_possible_rank.tax_id)
       return unless ncbi_ranked_lineage_object

       return ncbi_ranked_lineage_object.name
   end

   def _go_through_ranks(tax_id)
       ncbi_node_object = NcbiNode.find_by_tax_id(tax_id)
       return unless ncbi_node_object

       loop do
           return ncbi_node_object if GbifTaxonomy.possible_ranks.include?(ncbi_node_object.rank)

           ncbi_node_object = NcbiNode.find_by_tax_id(ncbi_node_object.parent_tax_id)
           return nil unless ncbi_node_object
           return nil if ncbi_node_object.parent_tax_id == ncbi_node_object.tax_id
       end
   end
end

class Polynomial < Monomial
    def taxonomy(first_specimen_info:, importer:)
        if taxonomy_params[:gbif]
            record = gbif_taxonomy_backbone(first_specimen_info: first_specimen_info, importer: importer)
            return record

        elsif taxonomy_params[:ncbi]
            record = ncbi_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
            return record

        elsif taxonomy_params[:unmapped]
            unmapped_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
        else 
            ## default is ncbi_taxonomy
            record = ncbi_taxonomy(first_specimen_info: first_specimen_info, importer: importer)
            return record
        end
    end


    def gbif_taxonomy_backbone(first_specimen_info:, importer:)
        records = _get_gbif_records(current_name: name, importer: importer, first_specimen_info: first_specimen_info)
        record  = _gbif_taxonomy_object(records: records)
        return record unless record.nil?

        records = _get_gbif_records(current_name: _ncbi_next_highest_taxa_name(name), importer: importer, first_specimen_info: first_specimen_info)
        record  = _gbif_taxonomy_object(records: records)
        return record unless record.nil?

        cutted_name = _remove_last_name_part(name)
        return nil if cutted_name.blank?
        
        nomial = Nomial.generate(name: cutted_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)
        nomial.gbif_taxonomy_backbone(first_specimen_info: first_specimen_info, importer: importer)

        
        source_lineage = importer.get_source_lineage(first_specimen_info)
        source_lineage.combined.reverse.each do |source_lineage_taxon_name|
            records = _get_gbif_records(current_name: source_lineage_taxon_name, importer: importer, first_specimen_info: first_specimen_info)
            record  = _gbif_taxonomy_object(records: records)
            
            return record unless record.nil?
        end

        return nil
    end

    private
    def _remove_last_name_part(name_to_clean)
        parts = name_to_clean.split(' ')
        parts.pop
        parts = parts.join(' ')
        
        return parts
    end
end
