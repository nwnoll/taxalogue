# frozen_string_literal: true

module GeoUtils

    require 'active_support/core_ext/string/output_safety'
    # NT
    # PA
    # NA

    # IM
    # AT
    # OC
    # AA
    # AN

    def get_areas_of_shapefiles(file_name:, attr_name:)

        # shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.shp', 'rb')
        # dbf = SHP::DBF.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.dbf', 'rb')
        # shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/realms.shp', 'rb')
        # dbf = SHP::DBF.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/realms.dbf', 'rb')   
        shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/fadaregions/fadaregions.shp', 'rb')
        dbf = SHP::DBF.open('/home/nnoll/bioinformatics/fadaregions/fadaregions.dbf', 'rb')   

        pathname = Pathname.new(file_name)
        shp = SHP::Shapefile.open(pathname.to_s, 'rb')
        dbf = SHP::DBF.open(pathname.sub_ext('.dbf').to_s, 'rb')

        field_num_of = Hash.new
        dbf.get_field_count.times do |field_num|
            field_num_of[dbf.get_field_info(field_num)[:name]] = field_num
        end

        # field_num_of.each do |field, num|
        #     puts "#{field}: #{dbf.read_string_attribute(shp_obj.get_shape_id, num)}"
        # end
        # exit

        eco_zones_of = Hash.new { |h, k| h[k] = [] }
        realms_of = Hash.new { |h, k| h[k] = [] }
        
        areas_of = Hash.new { |h, k| h[k] = [] }

        shp.get_info[:number_of_entities].times do |i|
            # next unless i == 7520
            shp_obj = shp.read_object(i)
            # field_num_of.each do |field, num|
            #     puts "#{field}: #{dbf.read_string_attribute(shp_obj.get_shape_id, num)}"
            # end

            x_ary = shp_obj.get_x
            y_ary = shp_obj.get_y
            points = []

            x_ary.each_with_index do |longitude, index|
                latitude = y_ary[index]
                points.push(Geokit::LatLng.new(latitude, longitude))
            end
            # exit
            # polygon = Geokit::Polygon.new(points)
            # eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['ECO_NAME'])
            # realm_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['REALM'])
            
            # eco_zones_of[eco_name].push(polygon)
            # realms_of[realm_name].push(polygon)

            polygon = Geokit::Polygon.new(points)
            # eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['fadaregion'])
            # realm_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['name'])
            area_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of[attr_name])
            # eco_zones_of[eco_name].push(polygon)
            # realms_of[realm_name].push(polygon)
            areas_of[area_name].push(polygon)
        end

        return areas_of
    end

    def country_by_name(name)
        ISO3166::Country.find_country_by_name(name)
    end

    def countries_by_region(region)
        countries = ISO3166::Country.find_all_countries_by_region(region)
        country_names = []
        countries.each { |country| country_names.push(country.data['name']) }

        return country_names.sort
    end

    def all_countries
        # ISO3166::Country.all_names_with_codes
        ISO3166::Country.all
    end

    def all_country_names
        countries = ISO3166::Country.all
        country_names = []
        countries.each { |country| country_names.push(country.data['name']) }

        return country_names.sort
    end

    def all_continent_names
        ['Antarctica', 'Asia', 'Australia', 'Europe', 'North America', 'South America', 'America', 'Eurasia']
    end

    def all_country_names_by_continent(continent)
        country_names = []
        ISO3166::Country.find_all_by(:continent, continent).each { |c| country_names.push(c[1]['name']) }

        return country_names.sort
    end

    def get_continent_of_country_hash
        hash = Hash.new

        australian_countries.each do |c|
            hash[c] = 'Australia'
        end
        antarctic_countries.each do |c|
            hash[c] = 'Antarctica'
        end
        asian_countries.each do |c|
            hash[c] = 'Asia'
        end
        european_countries.each do |c|
            hash[c] = 'Europe'
        end
        north_american_countries.each do |c|
            hash[c] = 'North America'
        end
        south_american_countries.each do |c|
            hash[c] = 'South America'
        end

        return hash

    end

    def australian_countries
        all_country_names_by_continent('Australia')
    end

    def antarctic_countries
        all_country_names_by_continent('Antarctica')
    end

    def asian_countries
        all_country_names_by_continent('Asia')
    end

    def european_countries
        all_country_names_by_continent('Europe')
    end

    def north_american_countries
        all_country_names_by_continent('North America')
    end

    def south_american_countries
        all_country_names_by_continent('South America')
    end

    def american_countries
        sac = south_american_countries
        nac = north_american_countries

        (sac + nac).sort
    end

    def eurasian_countries
        ac = asian_countries
        ec = european_countries

        (ac + ec).sort
    end

    def specimen_is_from_area(specimen:, region_params:)
        if region_params[:country_ary] && !specimen.location.nil?
            country_ary = region_params[:country_ary]
            country_ary.each do |country|
                return true if specimen.location.match?(country)
            end

        elsif region_params[:continent_ary] && !specimen.location.nil?
            continent_of = get_continent_of_country_hash

            continent_ary = region_params[:continent_ary]
            continent_ary.each do |continent|
                return true if continent_of[specimen.location] == continent
            end

            locations = specimen.location.split(', ')
            locations.each do |loc|
                continent_ary.each do |continent|
                    return true if continent_of[loc] == continent
                end
            end

            ## TODO:
            ## NEXT:
            ## add option to specify a country and a continent they are additive e.g 
            ## Europe AND Georgia or Russia etc...

            # continent_ary.each do |continent|
            #     countries_by_continent = all_country_names_by_continent(continent)
                
            #     countries_by_continent.bsearch {|country| x <=>  4 }
            #     continent_of
            #     return true if specimen.location.match?(continent)
            # end


            # all_country_names_by_continent

        end

        return false



        #     if specimen.location  
        # region_params[:continent_ary] 
        # region_params[:biogeo_ary] 
        # region_params[:terreco_ary] 
        # specimen.lat
        # specimen.long
        # specimen.location
        # if 
      ## TODO:
      ## NEXT implement a function that works for all importer/classifiers that uses location info of specimen
      ## object and gives true or false if its in area
      ## should handle shapefiles and country strings, maybe even states and continent specimen info?
    end
end