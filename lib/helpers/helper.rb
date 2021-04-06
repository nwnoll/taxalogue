# frozen_string_literal: true

class Helper
  include REXML

  def self.is_extinct?(taxon_name)

    file_name = Pathname.new('fm_data/GBIF_ZOOLOGIAL_NAMES/names.txt')

    unless File.exists?(file_name)

      config_name = 'lib/configs/gbif_zoological_names_config.json' 
      params = Helper.json_file_to_hash(config_name)
      config = Config.new(params)
      
      config.file_manager.create_dir

      downloader = HttpDownloader2.new(address: config.address, destination: config.file_manager.file_path)
      downloader.run

      unless File.exists?(config.file_manager.file_path)
        return false
      end

      Helper.extract_zip(name: config.file_manager.file_path, destination: config.file_manager.dir_path, files_to_extract: ['zoological names/names.txt'])
    end

    file  = File.open(file_name, 'r')
    csv   = CSV.new(file, headers: false, col_sep: "\t", liberal_parsing: true)

    csv.each do |row|
      taxon_without_author = row[3].split(' ')[0]
      return true if taxon_without_author == taxon_name && row[2] == 'true'
    end

    return false
  end

  def self._get_char_pos(seq)

    char_pos = 0
    # char_pos_to_start = 0

    seq.each_char do |char|
      if char =~ /[ACGT]/
        return char_pos
      end

      char_pos += 1
    end

    return 0
  end

  def self.filter_seq(seq, criteria)

    seq = seq.dup
    seq.upcase!

    return nil if seq =~ /[^ACGTN-]/

    start_pos = _get_char_pos(seq)
    end_pos   = (seq.size - _get_char_pos(seq.reverse) - 1)
    seq       = seq[start_pos..end_pos]

    return seq unless criteria

    if criteria[:max_N]
      return nil if seq.count('N') > criteria[:max_N]
    end

    if criteria[:max_G]
      return nil if seq.count('-') > criteria[:max_G]
    end

    seq_length = seq.size
    if criteria[:min_length]
      return nil if seq_length < criteria[:min_length]
    end

    if criteria[:max_length]
      return nil if seq_length > criteria[:max_length]
    end

    return seq
  end

  def self.json_file_to_hash(file_name)
    file = File.read(file_name)
    hash = JSON.parse(file)

    return hash
  end

  def self.new_ncbi_taxonomy_available?
    ncbi_taxonomy_update_config_name = 'lib/configs/ncbi_taxonomy_update_config.json' 
    params = Helper.json_file_to_hash(ncbi_taxonomy_update_config_name)
    config = Config.new(params)
    
    downloader = HttpDownloader2.new(address: config.address, destination: config.file_manager.file_path)
    downloader.run

    unless File.exists?('fm_data/NCBI_TAXONOMY/NCBI_TAXONOMY.zip')
      puts "The NCBI Taxonomy has not been setup yet, please use setup --ncbi_taxonomy"
      return true
    end

    md5_sum_download    = Digest::MD5.hexdigest(File.read('fm_data/NCBI_TAXONOMY/NCBI_TAXONOMY.zip'))
    check_file          = File.read(config.file_manager.file_path)
    check_file          =~ /^(.*?)\s/
    md5_sum_check_file  = $1

    if md5_sum_download == md5_sum_check_file
      return false
    else
      return true
    end
  end

  def self.new_gbif_taxonomy_available?

    unless File.exists?('fm_data/GBIF_TAXONOMY/eml.xml') || File.exists?('fm_data/GBIF_TAXONOMY/Taxon.tsv')
      puts "The GBIF Taxonomy has not been setup yet, please use setup --gbif_taxonomy"
      return true
    end


    file                          = File.new("fm_data/GBIF_TAXONOMY/eml.xml")
    doc                           = Document.new(file)
    timestamp_local_gbif_backbone = doc.get_elements('//dateStamp').first.to_s
    timestamp_local_gbif_backbone =~ />(.*?)</
    timestamp_local_gbif_backbone = $1

    gbif_backbone_dataset         = GbifApi.new(path: 'dataset/', query: 'd7dddbf4-2cf0-4f39-9b2a-bb099caae36c')
    gbif_backbone_modified_at 	  = gbif_backbone_dataset.response_hash['modified']
    
    return false if timestamp_local_gbif_backbone.nil? || gbif_backbone_modified_at.nil?
    
    datetime_local                = DateTime.parse(timestamp_local_gbif_backbone ,"%Y-%m-%dT%H:%M:%S")
    datetime_remote               = DateTime.parse(gbif_backbone_modified_at,     "%Y-%m-%dT%H:%M:%S")

    if datetime_remote > datetime_local
      return true
    else
      return false
    end
  end

  def self.setup_taxonomy
    gbif_taxonomy_job 	= GbifTaxonomyJob.new
    ncbi_taxonomy_job 	= NcbiTaxonomyJob.new
  
    multiple_jobs 		  = MultipleJobs.new(jobs: [gbif_taxonomy_job, ncbi_taxonomy_job])
    multiple_jobs.run

    GbifHomonymImporter.new(file_name: 'homonyms.txt').run
  end
  
  def self.constantize(s)
      Object.const_get(s)
  end

  def self.generate_index_by_column_name(file:, separator:)
    column_names          = file.first.chomp.split(separator)
    num_columns           = column_names.size
    index_by_column_name  = Hash.new
    (0...num_columns).each do |index|
        index_by_column_name[column_names[index]] = index
    end

    return index_by_column_name
  end

  def self.extract_zip(name:, destination:, files_to_extract:, retain_hierarchy: false)
    FileUtils.mkdir_p(destination)
    Zip::File.open(name) do |zip_file|
      zip_file.each do |f|
        
        pathname  = Pathname.new(f.name)
        basename  = pathname.basename
        dirname   = pathname.dirname
        
        next unless files_to_extract.include?(f.name)

        if retain_hierarchy
          dir_path = File.join(destination, dirname)
          FileUtils.mkpath(dir_path)

          fpath = File.join(destination, pathname)
          zip_file.extract(f, fpath) unless File.exist?(fpath)
        else
          fpath = File.join(destination, basename)
          zip_file.extract(f, fpath) unless File.exist?(fpath)
        end
      end
    end
  end

  def self.create_marker_objects(query_marker_names:)
    return [] if query_marker_names.nil?
    marker_names = query_marker_names.split(',')
    marker_objects = []
    marker_names.each do |marker_name|
      marker = Marker.new(query_marker_name: marker_name)
      marker_objects.push(marker)
    end
    return marker_objects
  end

  def self.normalize(string)
    string.tr(
    "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
    "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
    )
  end

  def self.latinize_rank(rank)
    GbifTaxonomy.rank_mappings["#{rank}"]
  end

  def self.get_source_db(taxonomy_params)
    if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
      return GbifTaxonomy
    else
      return NcbiTaxonomy
    end
  end

  def self.print_all_countries
    print 'Antarctica: '
    p antarctic_countries
    puts
    puts

    print 'Asia: '
    p asian_countries
    puts
    puts

    print 'Australia: '
    p australian_countries
    puts
    puts

    print 'Europe: '
    p european_countries
    puts
    puts

    print 'North America: '
    p north_american_countries
    puts
    puts

    print 'South America: '
    p south_american_countries
    puts
    puts '---------'
    puts

    print 'America: '
    p american_countries
    puts
    puts

    print 'Eurasia: '
    p eurasian_countries
  end

  def self.print_all_continents
    puts 'Antarctica'
    puts 'Asia'
    puts 'Australia'
    puts 'Europe'
    puts 'North America'
    puts 'South America'
    puts '---------'
    puts 'America'
    puts 'Eurasia'
  end

  def self.print_all_regions(regions)
    if regions.nil?
      puts 'Please download region shapefiles'
    end

    regions.each { |region| puts region }
  end


  def self.check_valid_names(valid_names, names)
    invalid_names = []
    # names.each { |e| valid_names.include?(e) ? nil : invalid_names.push(e) }
    names.each { |e| valid_names.find { |v| /#{e}/ =~ v } ? nil : invalid_names.push(e) } 
    if invalid_names.any?
      joined_invalid_names = invalid_names.join(' ')
      abort "Please only use valid names. The following names are invalid: #{joined_invalid_names}, use region -h to see available options"
    end
  end

  def self.get_shape_fada_regions
    address = 'http://geo.vliz.be/geoserver/wfs?request=getfeature&service=wfs&version=1.0.0&typename=MarineRegions:fadaregions&outputformat=SHAPE-ZIP'
    destination_dir = Pathname.new('fm_data/SHAPEFILES/fada_regions/')
    FileUtils.mkdir_p(destination_dir)
    destination_file = destination_dir + Pathname.new('fada_regions.zip')
    downloader = HttpDownloader2.new(address: address, destination: destination_file)
    downloader.run

    extract_zip(name: destination_file, destination: destination_dir, files_to_extract: ['fadaregions.shp', 'fadaregions.dbf', 'fadaregions.shx'], retain_hierarchy: false)
  end

  def self.get_shape_terreco_regions
    address = 'http://assets.worldwildlife.org/publications/15/files/original/official_teow.zip'
    destination_dir = Pathname.new('fm_data/SHAPEFILES/terreco_regions/')
    FileUtils.mkdir_p(destination_dir)
    destination_file = destination_dir + Pathname.new('terreco_regions.zip')
    downloader = HttpDownloader2.new(address: address, destination: destination_file)
    downloader.run

    extract_zip(name: destination_file, destination: destination_dir, files_to_extract: ['official/wwf_terr_ecos.shp', 'official/wwf_terr_ecos.dbf', 'official/wwf_terr_ecos.shx'], retain_hierarchy: false)
  end


  def self.check_fada(params)
    terrecos_shapefile_pathname = Pathname.new('fm_data/SHAPEFILES/terreco_regions/wwf_terr_ecos.shp')

    if File.file?(terrecos_shapefile_pathname) && File.file?(terrecos_shapefile_pathname.sub_ext('.dbf')) && File.file?(terrecos_shapefile_pathname.sub_ext('.shx'))
      $eco_zones_of = get_areas_of_shapefiles(file_name: terrecos_shapefile_pathname, attr_name: 'ECO_NAME')
      
      return params
    else
      Helper.get_shape_terreco_regions

      if File.file?(terrecos_shapefile_pathname) && File.file?(terrecos_shapefile_pathname.sub_ext('.dbf')) && File.file?(terrecos_shapefile_pathname.sub_ext('.shx'))
        $eco_zones_of = get_areas_of_shapefiles(file_name: terrecos_shapefile_pathname, attr_name: 'ECO_NAME')
        
        return params
      else
        puts
        puts "files #{terrecos_shapefile_pathname.sub_ext('.*').to_s} are missing"
        puts "if you want to use terrestrial ecoregions to filter your sequences you have two options"
        puts "at first press n to exit the program, then"
        puts "try the option setup --terrestrial_ecoregions"
        puts
        puts "or download the zip folder manually from http://assets.worldwildlife.org/publications/15/files/original/official_teow.zip"
        puts "put it into the folder fm_data/SHAPEFILES/terreco_regions/ and extract the following files:"
        puts 'official/wwf_terr_ecos.shp'
        puts 'official/wwf_terr_ecos.dbf'
        puts 'official/wwf_terr_ecos.shx'
        puts "without the official directory"
        puts
        puts "these files need to be available:"
        puts "fm_data/SHAPEFILES/terreco_regions/wwf_terr_ecos.shp"
        puts "fm_data/SHAPEFILES/terreco_regions/wwf_terr_ecos.dbf"
        puts "fm_data/SHAPEFILES/terreco_regions/wwf_terr_ecos.shx"
        puts 
        puts "if these files are present, start the program again with region -e 'ecoregion of your choice'"
        puts
        puts "do you want to continue without using terrestrial ecoregions? [Y/n]"
        
        user_input  = gets.chomp
        continue = (user_input =~ /y|yes/i) ? true : false
        continue ? params[:region][:terreco_ary] = :skip : exit

        return params
      end
    end
  end


  def self.check_biogeo(params)

		fada_regions_shapefile_pathname = Pathname.new('fm_data/SHAPEFILES/fada_regions/fadaregions.shp')

		if File.file?(fada_regions_shapefile_pathname) && File.file?(fada_regions_shapefile_pathname.sub_ext('.dbf')) && File.file?(fada_regions_shapefile_pathname.sub_ext('.shx'))
      $fada_regions_of = get_areas_of_shapefiles(file_name: fada_regions_shapefile_pathname, attr_name: 'name')
		
      return params
    else
			Helper.get_shape_fada_regions

			if File.file?(fada_regions_shapefile_pathname) && File.file?(fada_regions_shapefile_pathname.sub_ext('.dbf')) && File.file?(fada_regions_shapefile_pathname.sub_ext('.shx'))
				$fada_regions_of = get_areas_of_shapefiles(file_name: fada_regions_shapefile_pathname, attr_name: 'name')
			
        return params
      else
        puts
        puts "files #{fada_regions_shapefile_pathname.sub_ext('.*').to_s} are missing"
        puts "if you want to use terrestrial ecoregions to filter your sequences you have two options"
        puts "at first press n to exit the program, then"
        puts "try the option setup --biogeographic_realm"
        puts
        puts "or download the zip folder manually from http://geo.vliz.be/geoserver/wfs?request=getfeature&service=wfs&version=1.0.0&typename=MarineRegions:fadaregions&outputformat=SHAPE-ZIP"
        puts "put it into the folder fm_data/SHAPEFILES/fada_regions/ and extract the following files:"
        puts 'fadaregions.shp'
        puts 'fadaregions.dbf'
        puts 'fadaregions.shx'
        puts
        puts "these files need to be available:"
        puts "fm_data/SHAPEFILES/fadaregions/fadaregions.shp"
        puts "fm_data/SHAPEFILES/fadaregions/fadaregions.dbf"
        puts "fm_data/SHAPEFILES/fadaregions/fadaregions.shx"
        puts 
        puts "if these files are present, start the program again with region -b 'biogeographic realm of your choice'"
        puts
        puts "do you want to continue without using biogeographic realms? [Y/n]"
        
        user_input  = gets.chomp
        continue = (user_input =~ /y|yes/i) ? true : false
        continue ? params[:region][:biogeo_ary] = :skip : exit

        return params
			end
		end
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

      # record.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name || record.name == query_taxon_name


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

        taxonomic_status = _taxonomic_status(scientifc_name_record) unless scientifc_name_record.nil?
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
    records = get_ncbi_records(taxon_name)
    return nil if records.nil?

		records_with_available_ranks = records.select { |record| NcbiTaxonomy.possible_ranks.include?(record.taxon_rank) }
    chosen_taxon_object = nil

    return records.first if records.size == 1 || automatic

    puts "The following taxa are available:"
    record_counter = 1
    records_with_available_ranks.each do |record|
      puts "#{record_counter}) #{record.canonical_name}"
      _print_taxon_object(record)
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
        # _print_taxon_object(record)
        # puts
        puts "If this is not the taxon you intended to use please specify a lower or higher taxon with -t option"
        puts "Please confirm that the taxon is your intended choice [Y/n]"
        user_confirmation  = gets.chomp
        confirmed = (user_confirmation =~ /y|yes/i) ? true : false
        chosen_taxon_object = record if confirmed
      else
        3.times do 
          result = Helper._user_input_taxon_choice(records_with_available_ranks)
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
        result = Helper._user_input_taxon_choice(records_with_available_ranks)
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
      _print_taxon_object(chosen_taxon_object)
      
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
      record = Helper.choose_ncbi_record(taxon_name: taxon_name, automatic: automatic)
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
      record = Helper.choose_ncbi_record(taxon_name: taxon_name, automatic: automatic)
      taxon_object = record
    end

    return taxon_object
  end

  def self.assign_taxon_info_to_params(params, taxon_name)

    taxon_object = Helper.get_taxon_record(params, taxon_name)
		
		if taxon_object
			params[:taxon_rank]   = taxon_object.taxon_rank
			params[:taxon_object] = taxon_object
		else
			abort 'Cannot find Taxon, please only use Kingdom, Phylum, Class, Order, Family, Genus or Species'
		end

    return params
  end


  def self.get_inv_contaminants(file_manager, marker_objects)
    # contaminants_dir_path = file_manager.dir_path + 'contaminants/'
    contaminants_dir_path = Pathname.new('fm_data/NCBIGENBANK/inv_contaminants/')
    FileUtils.mkdir_p(contaminants_dir_path)
    
    wolbachia_contaminants_file_path = contaminants_dir_path + 'Wolbachia.gb'
    
    ncbi_api = NcbiApi.new(markers: marker_objects, taxon_name: 'Wolbachia', max_seq: 100, file_name: wolbachia_contaminants_file_path)
    ncbi_api.efetch
    
    human_contaminants_file_path = contaminants_dir_path + 'Homo_sapiens.gb'
    
    ncbi_api = NcbiApi.new(markers: marker_objects, taxon_name: 'Homo sapiens', max_seq: 10, file_name: human_contaminants_file_path)
    ncbi_api.efetch

    result_contaminants_dir_path = file_manager.dir_path + 'contaminants/'
    FileUtils.mkdir_p(result_contaminants_dir_path)
    
    wolbachia_result_contaminants_file_path = result_contaminants_dir_path + 'Wolbachia_output.out'
    ncbi_genbank_extractor = NcbiGenbankExtractor.new(file_name: wolbachia_contaminants_file_path, taxon_name: 'Wolbachia', markers: marker_objects, result_file_name: wolbachia_result_contaminants_file_path)
    ncbi_genbank_extractor.run

    human_result_contaminants_file_path = result_contaminants_dir_path + 'Homo_sapiens_output.out'
    ncbi_genbank_extractor = NcbiGenbankExtractor.new(file_name: human_contaminants_file_path, taxon_name: 'Homo sapiens', markers: marker_objects, result_file_name: human_result_contaminants_file_path)
    ncbi_genbank_extractor.run
  end

  def self.has_been_downloaded?(taxon:, dirs:, was_successful: true)
    taxon_name = taxon.canonical_name
    
    dirs.each do |dir|

      dirs_with_taxon_name = FileManager.directories_with_name_of(dir: dir, dir_name: taxon_name)

      ## TODO:
      ## NEXT:
      ## maybe also implement for non successful downloads
      ## should definitely do the same for GBOL and NCBI..
      ## need to specify what was successfull etc..
      ##
      successes = []
      dirs_with_taxon_name.each do |dir_with_taxon_name|
        file_path = dir_with_taxon_name + '.download_info.txt'
        success = DownloadInfoParser.download_was_successful?(file_path)
        successes.push(dir_with_taxon_name)
      end
    end
  end

  def self.select_from_download_dirs(dirs:)

    # precedence:
    ## only :same_taxon_found && :higher_taxon_found
    ## successfull highest precendence, after that comes most recent version and
    ## and after that comes distinction between same_taxon and higher_taxon

    precedence_of =
      {
        ## 0 higher precedence
        'true' => 0,
        'false' => 1,
        "" =>  9, # nil

        'same_taxon_found' => 0,
        'higher_taxon_found' => 1,
        'lower_taxon_found' => 2,
        'taxon_not_found' => 3,
        'dir_name_not_found' => 3,

        'not_versioned' => DateTime.new(1900)
    }
    only_dirs = dirs.map { |ary| ary[0] }

    desc_dirs_by_datetime = FileManager.sort_by_datetime(dirs: only_dirs, mode: 'desc')
    
    sorted = dirs.sort_by do |dir_and_state|
      dir, state  = dir_and_state
      file_path   = dir + '.download_info.txt'

      success = DownloadInfoParser.download_was_successful?(file_path)

      datetime = FileManager.datetime_of(dir: dir)
      datetime = precedence_of[datetime] if precedence_of.key?(datetime)
      
      ## defines precedence
      ## success | datetime of dir | download_state
      [precedence_of[success.to_s], precedence_of[state.to_s], desc_dirs_by_datetime.index(dir)]
    end

    same_or_higher_taxa_sorted = sorted.select { |dir_and_state| dir_and_state.last == :same_taxon_found || dir_and_state.last == :higher_taxon_found  }

    return same_or_higher_taxa_sorted.first
  end

  def self.download_dirs_for_taxon(params:, dirs:, only_successful: true)
    taxon_dirs = []
    dirs.each do |dir|
      taxon_download_status = Helper.taxon_download_status(dir: dir, params: params)
      taxon_dirs.push([dir, taxon_download_status]) unless taxon_download_status == :dir_name_not_found || taxon_download_status == :taxon_not_found
    end

    if only_successful
      successful_downloads = taxon_dirs.select do |dir_and_state|
        dir, state = dir_and_state
        file_path = dir + '.download_info.txt'

        DownloadInfoParser.download_was_successful?(file_path)
      end
    end

    return only_successful ? successful_downloads : taxon_dirs
  end

  def self.taxon_download_status(dir:, params:)

    taxon_query_object = params[:taxon_object]

    record_for_dir_name = nil
    taxon_object_from_marshal_dump = Helper._get_taxon_record_from_marshal_dump(dir)
    if taxon_object_from_marshal_dump
      ## since there are some differences between the taxonomies the taxon_object should only
      ## come from the same taxonomy as ther user specified taxonomy
      if taxon_object_from_marshal_dump.is_a?(GbifTaxonomy) && (params[:taxonomy][:gbif] || params[:taxonomy][:gbif_backbone])
        record_for_dir_name = taxon_object_from_marshal_dump
      elsif taxon_object_from_marshal_dump.is_a?(OpenStruct) && params[:taxonomy][:ncbi]
        record_for_dir_name = taxon_object_from_marshal_dump
      else
        record_for_dir_name = nil
      end
    else
      dir_name = FileManager.dir_name_of(dir: dir)
      record_for_dir_name = Helper.get_taxon_record(params, dir_name)
    end

    return :dir_name_not_found if record_for_dir_name.nil?

    if taxon_query_object.canonical_name == record_for_dir_name.canonical_name
      return :same_taxon_found

    elsif record_for_dir_name.taxon_rank
      
      ## works if taxon query is lower than dir_name
      ## e.g user wants Lentulidae, but has already downloaded seqs for Orthoptera
      return :higher_taxon_found if taxon_query_object.public_send(Helper.latinize_rank(record_for_dir_name.taxon_rank)) == record_for_dir_name.canonical_name
      
      ## works if taxon query is higher than dir name
      ## e.g. user wants Arthopoda, but has already downloaded seqs for Insecta  
      return :lower_taxon_found if record_for_dir_name.public_send(Helper.latinize_rank(taxon_query_object.taxon_rank)) == taxon_query_object.canonical_name
    
      ## did find no matches
      return :taxon_not_found
    else # no rank
      return :taxon_not_found
    end
  end

  def self._get_taxon_record_from_marshal_dump(dir)
    file_path = dir + '.taxon_object.dump'
    if File.file?(file_path)
      begin
        taxon_object = Marshal.load(File.open(file_path, 'rb').read)
        return taxon_object
      rescue StandardError
        return nil
      end
    else
      return nil
    end
  end

  def self.ask_user_about_gbol_download_dirs
    dirs = FileManager.directories_of(dir: GbolConfig::DOWNLOAD_DIR)
    current_release = nil
    dirs.each do |dir|
      if dir == GbolConfig::DOWNLOAD_DIR + GbolConfig::RELEASES[:current]
        success = DownloadInfoParser.download_was_successful?(dir + ".#{GbolJob::DOWNLOAD_INFO_NAME}")
        
        current_release = dir if success
        break
      end
    end

    if current_release

      ## NEXT
      ## TODO:
      ## Check for download success
      
      puts "You already have the latest GBOL Dataset release"
      return current_release
    else
      puts "A new GBOL dataset is available"
      puts "Do you want to download the new release? [Y/n]"
      user_input  = gets.chomp
      download_new_release = (user_input =~ /y|yes/i) ? true : false
      if download_new_release
        return nil
      else
        if dirs.empty?
          puts "No releases available. New GBOL dataset will be downloaded."
          return nil
        else
          3.times do
            puts "Please specify one of the following GBOL dataset releases:"
            dirs.each { |dir| puts dir.to_s }

            user_input  = gets.chomp
            user_path = Pathname.new(user_input)
            if dirs.include?(user_path)
              puts "You specified #{user_input}"
              return user_path
            else
              next
            end

            puts "No release specified. New GBOL dataset will be downloaded"
            return nil
          end
        end
      end
    end
  end

  def self.write_marshal_file(dir:, file_name:, data:)
    marshal_dump_file_name = dir + file_name
    data_dump = Marshal.dump(data)
    
    File.open(marshal_dump_file_name, 'wb') { |f| f.write(data_dump) }
  end

  def self.ask_user_about_bold_download_dirs(params)
    dirs = FileManager.directories_of(dir: BoldConfig::DOWNLOAD_DIR)
    return nil if Helper._is_nil_or_empty?(dirs)

    taxon_dirs = Helper.download_dirs_for_taxon(params: params, dirs: dirs)
    return nil if Helper._is_nil_or_empty?(taxon_dirs)

    selected_download_dir_and_state = Helper.select_from_download_dirs(dirs: taxon_dirs)
    return nil if Helper._is_nil_or_empty?(selected_download_dir_and_state)

    selected_download_dir, selected_download_state = selected_download_dir_and_state
    last_download_days = FileManager.is_how_old?(dir: selected_download_dir)
    return nil if last_download_days.nil?

    puts "You have already downloaded data for the taxon #{params[:taxon]}"
    puts "Sequences for #{params[:taxon]} are available in: #{selected_download_dir.to_s}"
    puts "The latest already downloaded version is #{last_download_days} days old"
    puts
    puts "Do you want to use the latest already downloaded version? [Y/n]"
    puts "Otherwise a new download will start"


    # nested_dir_name = FileManager.dir_name_of(dir: selected_download_dir)
    # download_dir = selected_download_dir + nested_dir_name

    user_input  = gets.chomp
    use_latest_download = (user_input =~ /y|yes/i) ? true : false

    return use_latest_download ? selected_download_dir : nil
  end

  def self.ask_user_about_genbank_download_dirs(params)
    dirs = FileManager.directories_with_name_of(dir: NcbiGenbankConfig::DOWNLOAD_DIR, dir_name: 'release')
    return nil if Helper._is_nil_or_empty?(dirs)

    byebug


    # success = DownloadInfoParser.download_was_successful?

    taxon_dirs = Helper.download_dirs_for_taxon(params: params, dirs: dirs)
    return nil if Helper._is_nil_or_empty?(taxon_dirs)

    selected_download_dir_and_state = Helper.select_from_download_dirs(dirs: taxon_dirs)
    return nil if Helper._is_nil_or_empty?(selected_download_dir_and_state)

    selected_download_dir, selected_download_state = selected_download_dir_and_state
    last_download_days = FileManager.is_how_old?(dir: selected_download_dir)
    return nil if last_download_days.nil?

    puts "You have already downloaded data for the taxon #{params[:taxon]}"
    puts "Sequences for #{params[:taxon]} are available in: #{selected_download_dir.to_s}"
    puts "The latest already downloaded version is #{last_download_days} days old"
    puts
    puts "Do you want to use the latest already downloaded version? [Y/n]"
    puts "Otherwise a new download will start"


    # nested_dir_name = FileManager.dir_name_of(dir: selected_download_dir)
    # download_dir = selected_download_dir + nested_dir_name

    user_input  = gets.chomp
    use_latest_download = (user_input =~ /y|yes/i) ? true : false

    return use_latest_download ? selected_download_dir : nil
  end

  def self.get_current_genbank_release_number
    file_path = NcbiGenbankConfig::DOWNLOAD_DIR + '.current_genbank_release_number.txt'
    
    begin
      downloader = HttpDownloader2.new(address: NcbiGenbankConfig::CURRENT_RELEASE_ADDRESS, destination: file_path)
      downloader.run
    rescue StandardError
      return nil
    end

    ## works until we reach Genbank release 1000
    file_content = File.read(file_path, 3) if File.file?(file_path)
    
    return file_content
  end


  def self.create_download_info_for_result_dir(already_downloaded_dir:, result_file_manager:, source:)
    download_info_str = source.class::DOWNLOAD_INFO_NAME

    data_dl_info_public_name = already_downloaded_dir + download_info_str
    data_dl_info_hidden_name = already_downloaded_dir + ".#{download_info_str}"

    result_dl_info_public_name = result_file_manager.dir_path + download_info_str
    result_dl_info_hidden_name = result_file_manager.dir_path + ".#{download_info_str}"

    dl_info_public = File.open(data_dl_info_public_name).read
    dl_info_hidden = File.open(data_dl_info_hidden_name).read

    dl_info_public.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
    dl_info_hidden.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
    
    File.open(result_dl_info_public_name, 'w') { |f| f.write(dl_info_public) }
    File.open(result_dl_info_hidden_name, 'w') { |f| f.write(dl_info_hidden) }
  end

  def self._is_nil_or_empty?(data)
    data.nil? || data.empty?
  end

end