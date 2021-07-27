# frozen_string_literal: true

class TaxonHelper
    def self.is_extinct?(taxon_name)

        file_name = Pathname.new('downloads/GBIF_ZOOLOGIAL_NAMES/names.txt')
    
        unless File.exists?(file_name)
    
            config_name = 'lib/configs/gbif_zoological_names_config.json' 
            params = MiscHelper.json_file_to_hash(config_name)
            config = Config.new(params)
            
            config.file_manager.create_dir
        
            downloader = HttpDownloader2.new(address: config.address, destination: config.file_manager.file_path)
            downloader.run
        
            unless File.exists?(config.file_manager.file_path)
                return false
            end
        
            MiscHelper.extract_zip(name: config.file_manager.file_path, destination: config.file_manager.dir_path, files_to_extract: ['zoological names/names.txt'])
        end
    
        file  = File.open(file_name, 'r')
        csv   = CSV.new(file, headers: false, col_sep: "\t", liberal_parsing: true)
    
        csv.each do |row|
            taxon_without_author = row[3].split(' ')[0]
            
            return true if taxon_without_author == taxon_name && row[2] == 'true'
        end
    
        return false
    end

    def self.get_ncbi_records(name)
      ncbi_name_records         = NcbiName.where(name: name)
      usable_ncbi_name_records  = ncbi_name_records.select { |record| record.name_class == 'scientific name' || record.name_class == 'synonym' || record.name_class == 'includes' || record.name_class == 'authority' } # || record.name_class == 'in-part'  }
      return nil if usable_ncbi_name_records.empty?
      
      ncbi_taxonomy_objects = []
  
      usable_ncbi_name_records.each do |usable_ncbi_name_record|
            ncbi_tax_id = usable_ncbi_name_record.tax_id
            ncbi_name_records_for_tax_id = NcbiName.where(tax_id: ncbi_tax_id)
            next if ncbi_name_records_for_tax_id.empty?
    
            ncbi_ranked_lineage_record = NcbiRankedLineage.find_by(tax_id: ncbi_tax_id)
            # next unless _belongs_to_correct_query_taxon_rank?(ncbi_ranked_lineage_record)
    
            # record.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name || record.name == query_taxon_name
    
    
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
    
            # if are_synonyms_allowed
            #   scientifc_name_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'scientific name' }.first
            #   canonical_name = scientifc_name_record.nil? ? usable_ncbi_name_record.name : scientifc_name_record.name 
    
            #   authority_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'authority' }.first
            #   authority = authority_record.nil? ? canonical_name : authority_record.name
    
            #   taxonomic_status = _taxonomic_name(usable_ncbi_name_record)
    
            #   if ncbi_node_record.rank == 'species' || ncbi_node_record.rank == 'subspecies' || ncbi_node_record.rank == 'genus' 
            #     genus = usable_ncbi_name_record.name.split(' ')[0]
            #   end
            # else
            scientifc_name_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'scientific name' }.first
            canonical_name = scientifc_name_record.name unless scientifc_name_record.nil?
    
            authority_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'authority' }.first
            authority = authority_record.nil? ? canonical_name : authority_record.name
    
            genus = ncbi_node_record.rank == 'genus' ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.genus
    
            taxonomic_status = TaxonHelper._taxonomic_status(scientifc_name_record) unless scientifc_name_record.nil?
            # end
    
            # combined = _get_combined(ncbi_ranked_lineage_record, ncbi_node_record.rank)
    
            # combined.push(genus)          if genus && !genus.empty?
            # combined.push(canonical_name) unless combined.include?(canonical_name)
    
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
                # combined:               combined,
                comment:                ''
            )
    
            ncbi_taxonomy_objects.push(obj)
        end
    
        # records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: importer.get_source_lineage(first_specimen_info), all_records: ncbi_taxonomy_objects) : ncbi_taxonomy_objects
    
        return ncbi_taxonomy_objects
    end

    def self._taxonomic_status(record)
        return nil if record.nil?
    
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

    def self.choose_ncbi_record(taxon_name:, automatic: false)
        records = TaxonHelper.get_ncbi_records(taxon_name)
        return nil if records.nil?
    
        records_with_available_ranks = records.select { |record| NcbiTaxonomy.possible_ranks.include?(record.taxon_rank) }
        chosen_taxon_object = nil
    
        return records.first if records.size == 1 || automatic
    
        puts "The following taxa are available:"
        record_counter = 1

        records_with_available_ranks.each do |record|
            puts "#{record_counter}) #{record.canonical_name}"
            TaxonHelper._print_taxon_object(record)
            puts
      
            record_counter += 1
        end
    
        record_counter = 1

        if records_with_available_ranks.size < records.size
            print "Since only taxa are allowed for the ranks: kingdom, phylum, class, order, family, genus and species. "
            print "Only taxa with these ranks can be chosen. Since your chosen taxon name might be a homonym, the only available choice "
            print "might have a rank that is currently not available, it could be not the taxon which you intended to use.\n"
      
            if records_with_available_ranks.size == 1
                record = records_with_available_ranks.first
                # puts "This is the only taxon where the rank is allowed:"
                # TaxonHelper._print_taxon_object(record)
                # puts
                puts "If this is not the taxon you intended to use please specify a lower or higher taxon with -t option"
                puts "Please confirm that the taxon is your intended choice [Y/n]"
                user_confirmation  = gets.chomp
                confirmed = (user_confirmation =~ /y|yes/i) ? true : false
                chosen_taxon_object = record if confirmed

            else
                3.times do 
                    
                    result = TaxonHelper._user_input_taxon_choice(records_with_available_ranks)
                    
                    if result.is_a?(OpenStruct)
                        chosen_taxon_object = result
                        break
                    
                    elsif result == 'invalid'
                        next
                    
                    elsif result == 'none'
                        break
                    
                    end
                end
            end
      
        else
            3.times do 
                result = TaxonHelper._user_input_taxon_choice(records_with_available_ranks)
                
                if result.is_a?(OpenStruct)
                    chosen_taxon_object = result
                    break
                
                elsif result == 'invalid'
                    next
                
                elsif result == 'none'
                    break

                end
            end
        end
          
        return chosen_taxon_object
    end

    def self._user_input_taxon_choice(records)
        
        puts "Choose a taxon by typing the number, or type none if your intended taxon is not vaialble: "
        user_input = gets.chomp
        unser_input_integer = user_input.to_i
        
        if (1..records.size).include?(user_input.to_i)
            record_index = unser_input_integer - 1 # counter starts with 1 not with 0
            chosen_taxon_object = records[record_index]
            puts "You have chosen:"
            TaxonHelper._print_taxon_object(chosen_taxon_object)
            
            return chosen_taxon_object
        
        elsif user_input == 'none'
    
            return 'none'
        
        else
            puts
            puts "Your choice is not available, please use a valid number: e.g. 1"
        
            return 'invalid'
        end
    end


    def self._print_taxon_object(obj)
        puts "   kingdom: #{obj.regnum}"
        puts "   phylum: #{obj.phylum}"
        puts "   class: #{obj.classis}"
        puts "   order: #{obj.ordo}"
        puts "   family: #{obj.familia}"
        puts "   genus: #{obj.genus}"
        puts "   canonical_name: #{obj.canonical_name}"
        puts "   scientific_name: #{obj.scientific_name}"
        puts "   taxonomic_status: #{obj.taxonomic_status}"
        puts "   taxon_rank: #{obj.taxon_rank}"
        puts "   comment: #{obj.comment}"
    end

    def self.get_taxon_record(params, taxon_name = nil, automatic: false)
        taxon_object = nil
        taxon_name = params[:taxon] if taxon_name.nil?
        
        if params[:taxonomy][:ncbi]
            record = TaxonHelper.choose_ncbi_record(taxon_name: taxon_name, automatic: automatic)
            taxon_object = record
      
        elsif params[:taxonomy][:gbif]
            # taxon_object = GbifTaxonomy.find_by_canonical_name(taxon_name)
            ## TODO: change?
            taxon_objects = GbifTaxonomy.where(canonical_name: taxon_name)
            taxon_objects = taxon_objects.select { |t| t.taxonomic_status == 'accepted' }
            taxon_object  = taxon_objects.first
        
        elsif params[:taxonomy][:gbif_backbone]
            ## TODO: change?
            taxon_objects = GbifTaxonomy.where(canonical_name: taxon_name)
            taxon_objects = taxon_objects.select { |t| t.taxonomic_status == 'accepted' }
            taxon_object  = taxon_objects.first
        
        else ## default ncbi
            record = TaxonHelper.choose_ncbi_record(taxon_name: taxon_name, automatic: automatic)
            taxon_object = record
        end
    
        return taxon_object
    end

    def self.assign_taxon_info_to_params(params, taxon_name)

        taxon_object = TaxonHelper.get_taxon_record(params, taxon_name)
            
        if taxon_object
            params[:taxon_rank]   = taxon_object.taxon_rank
            params[:taxon_object] = taxon_object
        else
            abort 'Cannot find Taxon, please only use Kingdom, Phylum, Class, Order, Family, Genus or Species'
        end

        return params
    end
end