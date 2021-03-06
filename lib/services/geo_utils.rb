# frozen_string_literal: true

module GeoUtils

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
end