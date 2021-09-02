# frozen_string_literal: true

class RegionHelper
    require_relative '../services/geo_utils'
    include GeoUtils

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
        destination_dir = Pathname.new('downloads/SHAPEFILES/fada_regions/')
        FileUtils.mkdir_p(destination_dir)
        destination_file = destination_dir + Pathname.new('fada_regions.zip')
        downloader = HttpDownloader2.new(address: address, destination: destination_file)
        downloader.run
    
        extract_zip(name: destination_file, destination: destination_dir, files_to_extract: ['fadaregions.shp', 'fadaregions.dbf', 'fadaregions.shx'], retain_hierarchy: false)
     end
    
    def self.get_shape_terreco_regions
        address = 'http://assets.worldwildlife.org/publications/15/files/original/official_teow.zip'
        destination_dir = Pathname.new('downloads/SHAPEFILES/terreco_regions/')
        FileUtils.mkdir_p(destination_dir)
        destination_file = destination_dir + Pathname.new('terreco_regions.zip')
        downloader = HttpDownloader2.new(address: address, destination: destination_file)
        downloader.run
    
        extract_zip(name: destination_file, destination: destination_dir, files_to_extract: ['official/wwf_terr_ecos.shp', 'official/wwf_terr_ecos.dbf', 'official/wwf_terr_ecos.shx'], retain_hierarchy: false)
    end
    
    
    def self.check_fada(params)
        terrecos_shapefile_pathname = Pathname.new('downloads/SHAPEFILES/terreco_regions/wwf_terr_ecos.shp')
    
        if File.file?(terrecos_shapefile_pathname) && File.file?(terrecos_shapefile_pathname.sub_ext('.dbf')) && File.file?(terrecos_shapefile_pathname.sub_ext('.shx'))
            $eco_zones_of = get_areas_of_shapefiles(file_name: terrecos_shapefile_pathname, attr_name: 'ECO_NAME')
            
            return params
        else
            RegionHelper.get_shape_terreco_regions
    
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
                puts "put it into the folder downloads/SHAPEFILES/terreco_regions/ and extract the following files:"
                puts 'official/wwf_terr_ecos.shp'
                puts 'official/wwf_terr_ecos.dbf'
                puts 'official/wwf_terr_ecos.shx'
                puts "without the official directory"
                puts
                puts "these files need to be available:"
                puts "downloads/SHAPEFILES/terreco_regions/wwf_terr_ecos.shp"
                puts "downloads/SHAPEFILES/terreco_regions/wwf_terr_ecos.dbf"
                puts "downloads/SHAPEFILES/terreco_regions/wwf_terr_ecos.shx"
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
    
        fada_regions_shapefile_pathname = Pathname.new('downloads/SHAPEFILES/fada_regions/fadaregions.shp')
    
        if File.file?(fada_regions_shapefile_pathname) && File.file?(fada_regions_shapefile_pathname.sub_ext('.dbf')) && File.file?(fada_regions_shapefile_pathname.sub_ext('.shx'))
            $fada_regions_of = get_areas_of_shapefiles(file_name: fada_regions_shapefile_pathname, attr_name: 'name')
            
            return params
        else
            RegionHelper.get_shape_fada_regions

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
                puts "put it into the folder downloads/SHAPEFILES/fada_regions/ and extract the following files:"
                puts 'fadaregions.shp'
                puts 'fadaregions.dbf'
                puts 'fadaregions.shx'
                puts
                puts "these files need to be available:"
                puts "downloads/SHAPEFILES/fadaregions/fadaregions.shp"
                puts "downloads/SHAPEFILES/fadaregions/fadaregions.dbf"
                puts "downloads/SHAPEFILES/fadaregions/fadaregions.shx"
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
end