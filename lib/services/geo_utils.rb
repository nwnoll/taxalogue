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

    def get_areas_of_eco_zones_and_realms
        # shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.shp', 'rb')
        # dbf = SHP::DBF.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.dbf', 'rb')
        # shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/realms.shp', 'rb')
        # dbf = SHP::DBF.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/realms.dbf', 'rb')   
        shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/fadaregions/fadaregions.shp', 'rb')
        dbf = SHP::DBF.open('/home/nnoll/bioinformatics/fadaregions/fadaregions.dbf', 'rb')   

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

        shp.get_info[:number_of_entities].times do |i|
            # next unless i == 7520
            shp_obj = shp.read_object(i)
            p i

            field_num_of.each do |field, num|
                puts "#{field}: #{dbf.read_string_attribute(shp_obj.get_shape_id, num)}"
            end

            x_ary = shp_obj.get_x
            y_ary = shp_obj.get_y
            points = []

            x_ary.each_with_index do |longitude, index|
                latitude = y_ary[index]
                p longitude
                p latitude
                points.push(Geokit::LatLng.new(latitude, longitude))
            end
            puts

            # exit
            # polygon = Geokit::Polygon.new(points)
            # eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['ECO_NAME'])
            # realm_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['REALM'])
            
            # eco_zones_of[eco_name].push(polygon)
            # realms_of[realm_name].push(polygon)

            polygon = Geokit::Polygon.new(points)
            eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['fadaregion'])
            realm_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['name'])
            
            eco_zones_of[eco_name].push(polygon)
            realms_of[realm_name].push(polygon)
        end

        return [eco_zones_of, realms_of]
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

    def all_country_names_by_continent(continent)
        country_names = []
        ISO3166::Country.find_all_by(:continent, continent).each { |c| country_names.push(c[1]['name']) }

        return country_names.sort
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

end