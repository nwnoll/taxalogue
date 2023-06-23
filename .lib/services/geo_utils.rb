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

    def _locality_matches_user_countries_or_continents(user_areas_ary:, specimen_location:)
        user_areas_ary.each do |area|
            return true if specimen_location.match?(area)
        end

        user_areas_ary.each do |area|
            return true if $continent_of[specimen_location] == area
        end

        locations = specimen_location.split(', ') # GBOL separates locations with a comma e.g Germany, Hesse, Europe
        locations.each do |location|
            user_areas_ary.each do |area|
                return true if $continent_of[location] == area
            end
        end

        return false
    end

    def _coords_match_user_shapefiles(user_areas_ary:, lat:, long:)

        specimen_locality = Geokit::LatLng.new(lat, long)

        user_areas_ary.each do |area|
            if $eco_zones_of.key?(area)
                polygons = $eco_zones_of[area]
                polygons.each do |polygon|
                    if polygon.contains?(specimen_locality)
                        return true
                    end
                end
            elsif $fada_regions_of.key?(area)
                polygons = $fada_regions_of[area]
                polygons.each do |polygon|
                    if polygon.contains?(specimen_locality)
                        return true
                    end
                end
            elsif $custom_regions_of.key?(area)
                polygons = $custom_regions_of[area]
                polygons.each do |polygon|
                    if polygon.contains?(specimen_locality)
                        return true
                    end
                end
            end
        end

        return false
    end

    def specimen_is_from_area(specimen:, region_params:)
        if region_params[:country_ary] && region_params[:continent_ary] && _location_is_present?(specimen.location)
            matches_country = _locality_matches_user_countries_or_continents(user_areas_ary: region_params[:country_ary], specimen_location: specimen.location)
            matches_continent = _locality_matches_user_countries_or_continents(user_areas_ary: region_params[:continent_ary], specimen_location: specimen.location)
            
            return matches_country || matches_continent

        elsif region_params[:country_ary] && _location_is_present?(specimen.location)
            return _locality_matches_user_countries_or_continents(user_areas_ary: region_params[:country_ary], specimen_location: specimen.location)

        elsif region_params[:continent_ary] && _location_is_present?(specimen.location)
            return _locality_matches_user_countries_or_continents(user_areas_ary: region_params[:continent_ary], specimen_location: specimen.location)
        
        elsif region_params[:biogeo_ary] == :skip && region_params[:terreco_ary] == :skip
            return true

        elsif region_params[:biogeo_ary] == :skip && region_params[:terreco_ary].nil?
            return true

        elsif region_params[:terreco_ary] == :skip && region_params[:biogeo_ary].nil?
            return true

        elsif region_params[:biogeo_ary] == :skip && region_params[:terreco_ary] && _lat_is_present?(specimen.lat) && _long_is_present?(specimen.long)
            return _coords_match_user_shapefiles(user_areas_ary: region_params[:terreco_ary], lat: specimen.lat, long: specimen.long)
            
        elsif region_params[:terreco_ary] == :skip && region_params[:biogeo_ary] && _lat_is_present?(specimen.lat) && _long_is_present?(specimen.long)
            return _coords_match_user_shapefiles(user_areas_ary: region_params[:biogeo_ary], lat: specimen.lat, long: specimen.long)
 
        elsif region_params[:biogeo_ary] && region_params[:terreco_ary] && _lat_is_present?(specimen.lat) && _long_is_present?(specimen.long)
            matches_fada    =  _coords_match_user_shapefiles(user_areas_ary: region_params[:biogeo_ary], lat: specimen.lat, long: specimen.long)
            matches_terreco =  _coords_match_user_shapefiles(user_areas_ary: region_params[:terreco_ary], lat:specimen.lat, long: specimen.long)
        
            return matches_fada || matches_terreco

        elsif region_params[:biogeo_ary] && _lat_is_present?(specimen.lat) && _long_is_present?(specimen.long)
            return _coords_match_user_shapefiles(user_areas_ary: region_params[:biogeo_ary], lat: specimen.lat, long: specimen.long)
        
        elsif region_params[:terreco_ary] && _lat_is_present?(specimen.lat) && _long_is_present?(specimen.long)
            return _coords_match_user_shapefiles(user_areas_ary: region_params[:terreco_ary], lat: specimen.lat, long: specimen.long)
        
        end

        return false
    end

    def _lat_is_present?(lat)
        !lat.nil? && !lat.blank?
    end

    def _long_is_present?(long)
        !long.nil? && !long.blank?
    end

    def _location_is_present?(loc)
        !loc.nil? && !loc.blank?
    end
end
