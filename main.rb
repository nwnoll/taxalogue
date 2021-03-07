# frozen_string_literal: true

require './requirements'
include GeoUtils

params = {
	import: Hash.new,
	download: Hash.new,
	setup: Hash.new,
	update: Hash.new,
	filter: Hash.new,
	taxonomy: Hash.new,
	region: Hash.new
}
CONFIG_FILE = 'default_config.yaml'

if File.exists? CONFIG_FILE
	config_options = YAML.load_file(CONFIG_FILE)
	params.merge!(config_options)

	taxon_object 			= GbifTaxonomy.find_by_canonical_name(params[:taxon])
	if taxon_object.nil?
		abort "Cannot find default Taxon, please only use Kingdom, Phylum, Class, Order, Family, Genus or Species\nMaybe the Taxonomy Database is not properly setup, run the program with --setup_taxonomy to fix the issue."
	end

	params[:taxon_object] 	= taxon_object
	params[:marker_objects] = Helper.create_marker_objects(query_marker_names: params[:markers])
end

## modified after https://gist.github.com/rkumar/445735
subtext = <<HELP
Commonly used commands are:
   import   :  imports files into SQL database, in general this happens after first start automatically
   download :  downloads sequence and specimen data
   setup    :  setup Taxonomies
   update   :  update taxonomies or sequences
   filter   :  filter sequences
   taxonomy :  different options regarding the used taxonomy
   region   :  filter by country, continent, biogeographic regions etc.

See 'bundle exec ruby main.rb COMMAND --help' for more information on a specific command.
HELP

global = OptionParser.new do |opts|
	opts.banner = "Usage: bundle exec ruby main.rb [params] [subcommand [params]]"
	opts.on('-t TAXON', 	String, '--taxon', 'Choose a taxon to build your database, if you want a database for a species, put "" around the option: e.g.: -t "Apis mellifera". default: Arthropoda') do |taxon_name|
		abort 'Taxon is extinct, please choose another Taxon' if Helper.is_extinct?(taxon_name)

		## TODO: should be changed
		taxon_objects 	= GbifTaxonomy.where(canonical_name: taxon_name)
		taxon_objects 	= taxon_objects.select { |t| t.taxonomic_status == 'accepted' }
		taxon_object 	= taxon_objects.first
		####
		
		params[:taxon_object] = taxon_object
		if taxon_object
			params[:taxon_rank] = taxon_object.taxon_rank
		else
			abort 'Cannot find Taxon, please only use Kingdom, Phylum, Class, Order, Family, Genus or Species'
		end
		taxon_name
	end
	
	opts.on('-m MARKERS', 	String, '--markers') do |markers|
		params[:marker_objects] = Helper.create_marker_objects(query_marker_names: markers)
	end
  
  opts.separator ""
  opts.separator subtext
end

subcommands = { 
	import: OptionParser.new do |opts|
		opts.banner = "Usage: import [options]"
		opts.on('-f FASTA', String, '--fasta')
		opts.on('-g GBOL', String, '--gbol')
		opts.on('-o BOLD', String, '--bold')
		opts.on('-k GENBANK', String, '--genbank')
		opts.on('-b GBIF', String, '--gbif')
		opts.on('-n NODES', String, '--nodes')
		opts.on('-m NAMES', String, '--names')
		opts.on('-l LINEAGE', String, '--lineage')
		opts.on('-a', '--all_seqs') 
   end,
   download: OptionParser.new do |opts|
		opts.banner = "Usage: download [options]"
		opts.on('-g', '--gbol')
		opts.on('-o', '--bold')
		opts.on('-k', '--genbank')
   end,
   setup: OptionParser.new do |opts|
		opts.banner = "Usage: setup [options]"
		opts.on('-t', '--taxonomies')
		opts.on('-n', '--ncbi_taxonomy')
		opts.on('-g', '--gbif_taxonomy')
   end,
   update: OptionParser.new do |opts|
		opts.banner = "Usage: update [options]"
		opts.on('-A', '--all_taxonomies')
		opts.on('-b', '--gbif_taxonomy')
		opts.on('-n', '--ncbi_taxonomy')
		opts.on('-a', '--all_sequences')
		opts.on('-o', '--bold_sequences')
		opts.on('-k', '--genbank_sequences')
		opts.on('-g', '--gbol_sequences')
	end,
	filter: OptionParser.new do |opts|
		opts.banner = "Usage: filter [options]"
		opts.on('-N MAX_N', Integer, '--max_N')
		opts.on('-G MAX_GAPS', Integer,'--max_G')
		opts.on('-l MIN_LENGTH', Integer,'--min_length')
		opts.on('-L MAX_LENGTH', Integer,'--max_length')
	end,
	taxonomy: OptionParser.new do |opts|
		opts.banner = "Usage: taxonomy [options]"
		opts.on('-b', '--gbif', 'Taxon information is mapped to GBIF Taxonomy backbone + additional available datasets from the GBIF API')
		opts.on('-B', '--gbif_backbone', 'Taxon information is mapped to GBIF Taxonomy backbone')
		opts.on('-n', '--ncbi', 'Taxon information is mapped to NCBI Taxonomy')
		opts.on('-u', '--unmapped', 'No mapping takes place, original specimen information is used but only standard ranks are used (e.g. no subfamilies)')
		opts.on('-s', '--synonyms_allowed', 'Allows Taxon information of synonyms to be set to sequences')
		opts.on('-r', '--retain', 'retains sequences for taxa that are not present in chosen taxonomy')
	end,
	region: OptionParser.new do |opts|
		opts.set_summary_width 80

		opts.banner = "Usage: region [options]"
		opts.on('-c COUNTRY', String, '--country')
		opts.on('-C', '--country_list') { Helper.print_all_countries; exit }
		opts.on('-k CONTINENT', String,'--continent')
		opts.on('-K', '--continent_list') { Helper.print_all_continents; exit }
		opts.on('-b BIOGEOGRAPHIC_REALM', String,'--biogeographic_realm')
		opts.on('-B', '--biogeographic_realm_list')
		opts.on('-t TERRESTRIAL_ECOREGION', String,'--terrestrial_ecoregion')
		opts.on('-T ', '--terrestrial_ecoregion_list')
	end
 }

global.order!
loop do 
	break if ARGV.empty?
	command = ARGV.shift.to_sym
	subcommands[command].order!(into: params[command]) unless subcommands[command].nil?
end


exit

# file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

# genbank_job = NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], filter_params: params[:filter], taxonomy_params: params[:taxonomy])
# file_manager.create_dir

# genbank_job.run

# exit


shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.shp', 'rb')
# shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/europe_biogeo/BiogeoRegions2016.shp', 'rb')
# dbf = SHP::DBF.open('/home/nnoll/bioinformatics/europe_biogeo/BiogeoRegions2016.dbf', 'rb')
dbf = SHP::DBF.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.dbf', 'rb')


## https://science.sciencemag.org/content/339/6115/74.full?ijkey=aasSpkcHziAV.&keytype=ref&siteid=sci
## An Update of Wallace’s Zoogeographic Regions of the World

# a litle bit like countries
# shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/Regions.shp', 'rb')
# dbf = SHP::DBF.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/Regions.dbf', 'rb')

# i think these are the old wallace realms, but here is no name
# shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/realms.shp', 'rb')
# dbf = SHP::DBF.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/realms.dbf', 'rb')

# new realms from paper
# shp = SHP::Shapefile.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/newRealms.shp', 'rb')
# dbf = SHP::DBF.open('/home/nnoll/bioinformatics/CMEC_updated_wallace_regions/newRealms.dbf', 'rb')

# 50.7374, 7.0982



## shape files biogegraphic freshwater and other
# https://data.freshwaterbiodiversity.eu/shapefiles

field_num_of = Hash.new
dbf.get_field_count.times do |field_num|
	field_num_of[dbf.get_field_info(field_num)[:name]] = field_num
end

$areas_of = Hash.new { |h, k| h[k] = [] }
shape_objects_of = Hash.new { |h, k| h[k] = [] }

$splitted_areas_of = Hash.new { |h1, k1| h1[k1] = Hash.new { |h2, k2| h2[k2] = Hash.new { |h3, k3| h3[k3] = [] } } }
positive_y = 0
total = 0
positive_x = 0

$geo_hashes_of = Hash.new
shp.get_info[:number_of_entities].times do |i|
	# next unless i == 7520
	shp_obj = shp.read_object(i)

	total += 1
	positive_y += 1 if shp_obj.get_y_min.positive?
	positive_x += 1 if shp_obj.get_x_min.positive?



	x_ary = shp_obj.get_x
	y_ary = shp_obj.get_y
	points = []
	# byebug unless x_ary.size == y_ary.size
	points = []


	x_ary.each_with_index do |longitude, index|
		latitude = y_ary[index]
		points.push(Geokit::LatLng.new(latitude, longitude))
		# encoded_lat_long = GeoHash.encode(latitude, longitude)
	end


	polygon = Geokit::Polygon.new(points)
	whole_area_polygon = nil

	
	eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['ECO_NAME'])
	# puts eco_name

	# if shp_obj.get_x_min.positive? && shp_obj.get_y_min.positive?
	# 	$splitted_areas_of[:positive_x][:positive_y][eco_name]
	# end

	field_num_of.each do |field, num|
		# puts "#{field}: #{dbf.read_string_attribute(shp_obj.get_shape_id, num)}"
	end
	# puts
	# puts
	# eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['name'])
	# eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['Regions']) 
	# eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['fullupgmar'])
	# eco_name = dbf.read_string_attribute(shp_obj.get_shape_id, field_num_of['Realm'])
	# p eco_name
	$areas_of[eco_name].push(polygon)
	shape_objects_of[eco_name].push(shp_obj)

end


$polygons_of = Hash.new { |h, k| h[k] = [] }
shape_objects_of.each do |name, shape_objects|
	max_x = shape_objects.inject { |n1, n2| n2.get_x_max > n1.get_x_max ? n2 : n1 }.get_x_max
	max_y = shape_objects.inject { |n1, n2| n2.get_y_max > n1.get_y_max ? n2 : n1 }.get_y_max
	min_x = shape_objects.inject { |n1, n2| n2.get_x_min < n1.get_x_min ? n2 : n1 }.get_x_min
	min_y = shape_objects.inject { |n1, n2| n2.get_y_min < n1.get_y_min ? n2 : n1 }.get_y_min

	polygons = []
	shape_objects.each do |shp_obj|
		x_ary = shp_obj.get_x
		y_ary = shp_obj.get_y
		points = []

		x_ary.each_with_index do |longitude, index|
			latitude = y_ary[index]
			points.push(Geokit::LatLng.new(latitude, longitude))
		end

		polygon = Geokit::Polygon.new(points)
		polygons.push(polygon)
	end

	point_lower_left = Geokit::LatLng.new(min_y, min_x)
	point_upper_left = Geokit::LatLng.new(max_y, min_x)
	point_upper_right = Geokit::LatLng.new(max_y, max_x)
	point_lower_right = Geokit::LatLng.new(min_y, max_x)

	rect_polygon = Geokit::Polygon.new([point_lower_left, point_upper_left, point_upper_right, point_lower_right, point_lower_left])
	# p rect_polygon
	$polygons_of[name] = [rect_polygon, polygons].flatten

	# if min_x.positive?
	# 	if min_y.positive?
	# 		$splitted_areas_of[:east][:north][name] = [rect_polygon, polygons].flatten
	# 	elsif min_y.negative? && max_y.positive? # put it in north and south since the shape is across the equatorial border
	# 		$splitted_areas_of[:east][:north][name] = [rect_polygon, polygons].flatten
	# 		$splitted_areas_of[:east][:south][name] = [rect_polygon, polygons].flatten
	# 	elsif min_y.negative? && max_y.negative?
	# 		$splitted_areas_of[:east][:south][name] = [rect_polygon, polygons].flatten
	# 	end
	# elsif min_x.negative? && max_x.positive? # put it in west and east since it the shape files corss the meridian
	# 	if min_y.positive?
	# 		$splitted_areas_of[:west][:north][name] = [rect_polygon, polygons].flatten
	# 		$splitted_areas_of[:east][:north][name] = [rect_polygon, polygons].flatten
	# 	elsif min_y.negative? && max_y.positive? # put it in north and south since the shape is across the equatorial border
	# 		$splitted_areas_of[:west][:north][name] = [rect_polygon, polygons].flatten
	# 		$splitted_areas_of[:west][:south][name] = [rect_polygon, polygons].flatten

	# 		$splitted_areas_of[:east][:north][name] = [rect_polygon, polygons].flatten
	# 		$splitted_areas_of[:east][:south][name] = [rect_polygon, polygons].flatten
	# 	elsif min_y.negative? && max_y.negative?
	# 		$splitted_areas_of[:west][:south][name] = [rect_polygon, polygons].flatten
	# 		$splitted_areas_of[:east][:south][name] = [rect_polygon, polygons].flatten
	# 	end
	# elsif min_x.negative? && max_x.negative?
	# 	if min_y.positive?
	# 		$splitted_areas_of[:west][:north][name] = [rect_polygon, polygons].flatten
	# 	elsif min_y.negative? && max_y.positive? # put it in north and south since the shape is across the equatorial border
	# 		$splitted_areas_of[:west][:north][name] = [rect_polygon, polygons].flatten
	# 		$splitted_areas_of[:west][:south][name] = [rect_polygon, polygons].flatten
	# 	elsif min_y.negative? && max_y.negative?
	# 		$splitted_areas_of[:west][:south][name] = [rect_polygon, polygons].flatten
	# 	end
	# else
	# 	byebug
	# end

end



	# byebug if name == 'Western European broadleaf forests'
	# if rect_polygon.contains?(Geokit::LatLng.new(47.997791, 7.842609))
	# 	puts name
	# 	$areas_of[name].each do |area|
	# 		if area.contains?(Geokit::LatLng.new(47.997791, 7.842609))
	# 			print '  '
	# 			puts name
	# 		end
	# 	end
	# end

	# shape_objects.each do |o| 
	# 	o.get_x.size.times do |i|
	# 		is_in_polygon = rect_polygon.contains?(Geokit::LatLng.new(o.get_x[i], o.get_y[i]))
	# 		puts name if
	# 	end
	# end
	# puts
# end


# require 'set'
# key_set = Set.new

# $splitted_areas_of[:west][:south].keys.each { |key| key_set.add(key) }
# $splitted_areas_of[:west][:north].keys.each { |key| key_set.add(key) }
# $splitted_areas_of[:east][:south].keys.each { |key| key_set.add(key) }
# $splitted_areas_of[:east][:north].keys.each { |key| key_set.add(key) }



# key_set.add(ws)
# key_set.add(wn)
# key_set.add(es)
# key_set.add(en)

# key_set.flatten!


# byebug

# exit
# pp $areas_of.keys

# lat_lng = Geokit::LatLng.new(39.848198, 9.253313)

# $areas_of.each do |eco_name, area_polygons|
# 	area_polygons.each do |polygon|
# 		# puts eco_name if polygon.contains?(lat_lng)
# 	end
# end


# (byebug) dbf.get_field_count
# 21
# (byebug) shp.read_object(0)
# #<SHP::ShapeObject:0x000055d274499728>
# (byebug) obj1 = shp.read_object(0)
# #<SHP::ShapeObject:0x000055d2744769a8>
# (byebug) obj1.get_x
# [-112.26972153261728, -112.28808561193952, -112.30207064976271, -112.31364454931621, -112.32077754892515, -112.3249896229128, -112.32949053728414, -112.33276367047719, -112.33673065761576, -112.34364354844712, -112.34729755532082, -112.34953267362367, -112.3503495739079, -112.35034152728085, -112.34899857875283, -112.3463435271005, -112.34335353459697, -112.33705168450768, -112.33472453290788, -112.33207652205424, -112.32678267964175, -112.32314258672734, -112.31819156415506, -112.31060057735618, -112.30532852789197, -112.30072066043601, -112.28854359912945, -112.28163154648843, -112.27669561134188, -112.27407056690295, -112.27078955472089, -112.2681656837484, -112.26747166216484, -112.26972153261728]
# (byebug) obj1.get_y
# [29.32647767382656, 29.326271814284382, 29.321869806370614, 29.320189905334644, 29.31684116737489, 29.315979172451478, 29.317375094607655, 29.320391909201362, 29.32004104273409, 29.31439214290276, 29.315589078677363, 29.318044138119717, 29.32027204798584, 29.32291385623114, 29.328520511270426, 29.33346231374918, 29.34005401005055, 29.349275779932782, 29.35355960301166, 29.357179579358444, 29.362443414557504, 29.365402226381207, 29.367363927002202, 29.367335931445552, 29.36632708557846, 29.364000269254745, 29.356033437917176, 29.352044657830334, 29.34740695079904, 29.344095931403558, 29.33880309481947, 29.335492243062106, 29.331038434986624, 29.32647767382656]
# (byebug) dbf.get_field_count
# 21
# (byebug) dbf.get_field_info(1)
# {:name=>"AREA", :type=>2, :width=>19, :decimals=>11}
# (byebug) dbf.get_field_info(0)
# {:name=>"OBJECTID", :type=>1, :width=>9, :decimals=>0}
# (byebug) dbf.get_field_info(3)
# {:name=>"ECO_NAME", :type=>0, :width=>99, :decimals=>0}
# (byebug) dbf.read_string_attribute(0,3)
# "Northern Mesoamerican Pacific mangroves"
# (byebug) 





# Shape:2 (Polygon)  nVertices=11940, nParts=10
#   Bounds:(-109.311660559818,20.4101455170804, 0)
#       to (-102.913947649646,28.2948610255889, 0)
# 	 (-109.117004604708,27.741424913157, 0) Ring

# 	 + (-108.67435462122,26.9762998125186, 0) Ring
#        (-108.67435462122,26.9762998125186, 0)  









# module RGeo
# 	module ImplHelper # :nodoc:
# 		module BasicLinearRingMethods # :nodoc:
# 			def validate_geometry
# 				super
# 				if @points.size > 0
# 					pp @points
# 					@points << @points.first if @points.first != @points.last
# 					@points = @points.chunk { |x| x }.map(&:first)
# 				  if !@factory.property(:uses_lenient_assertions) && !is_ring?
# 					raise Error::InvalidGeometry, "LinearRing failed ring test"
# 				  end
# 				end
# 			end
# 		end
# 	end
# end



# module Geokit
# 	class LatLng
# 		def initialize(lng, lat)
# 			puts "#{lng} #{lat}"
# 			# p lat
# 			# lng = lng.to_f if lng && !lng.is_a?(Numeric)
# 			# lat = lat.to_f if lat && !lat.is_a?(Numeric)
# 			@lng = lng
# 			@lat = lat
# 		end
# 	end
# end


# points = []
# points << Geokit::LatLng.new(-15.7535398925005, -144.636321651707)
# points << Geokit::LatLng.new(-15.7474843027267, -144.650146595179)  
# points << Geokit::LatLng.new(-15.7367370264651, -144.655242624677)  
# points << Geokit::LatLng.new(-15.7286895612189, -144.65484666357 )
# points << Geokit::LatLng.new(-15.7224368290823, -144.650405595988)  
# points << Geokit::LatLng.new(-15.7189212912491, -144.644042558005)  
# points << Geokit::LatLng.new(-15.7181682610671, -144.638137674851)  
# points << Geokit::LatLng.new(-15.7201619805583, -144.631240709635)  
# points << Geokit::LatLng.new(-15.7235600041088, -144.626693694796)  
# points << Geokit::LatLng.new(-15.7352302955489, -144.622054646661)  
# points << Geokit::LatLng.new(-15.7414375977703, -144.62222262    )
# points << Geokit::LatLng.new(-15.7498000549382, -144.63043168834 )
# points << Geokit::LatLng.new(-15.7535398925005, -144.636321651707)
# # polygon = Geokit::Polygon.new(points)
# # p polygon.contains? polygon.centroid 

# points << Geokit::LatLng.new(-15.7216299870818, -144.639510630592)
# points << Geokit::LatLng.new(-15.7237519496917, -144.64447070562 )
# points << Geokit::LatLng.new(-15.734393278697,  -144.651000711114) 
# points << Geokit::LatLng.new(-15.7423906201622, -144.646636589402)  
# points << Geokit::LatLng.new(-15.7464863533337, -144.642806562562)  
# points << Geokit::LatLng.new(-15.7476023199235, -144.639709616974)  
# points << Geokit::LatLng.new(-15.7442644784379, -144.628600577771)  
# points << Geokit::LatLng.new(-15.7391659343696, -144.624618670844)  
# points << Geokit::LatLng.new(-15.7348031537627, -144.625152598077)  
# points << Geokit::LatLng.new(-15.7263426283276, -144.629028557747)  
# points << Geokit::LatLng.new(-15.7218009779068, -144.634063566989)  
# points << Geokit::LatLng.new(-15.7216299870818, -144.639510630592)


# points2 = []
# points2 << Geokit::LatLng.new(-15.7216299870818, -144.639510630592)
# points2 << Geokit::LatLng.new(-15.7237519496917, -144.64447070562)
# points2 << Geokit::LatLng.new(-15.734393278697, -144.651000711114) 
# points2 << Geokit::LatLng.new(-15.7423906201622, -144.646636589402)  
# points2 << Geokit::LatLng.new(-15.7464863533337, -144.642806562562)  
# points2 << Geokit::LatLng.new(-15.7476023199235, -144.639709616974)  
# points2 << Geokit::LatLng.new(-15.7442644784379, -144.628600577771)  
# points2 << Geokit::LatLng.new(-15.7391659343696, -144.624618670844)  
# points2 << Geokit::LatLng.new(-15.7348031537627, -144.625152598077)  
# points2 << Geokit::LatLng.new(-15.7263426283276, -144.629028557747)  
# points2 << Geokit::LatLng.new(-15.7218009779068, -144.634063566989)  
# points2 << Geokit::LatLng.new(-15.7216299870818, -144.639510630592)

# polygon = Geokit::Polygon.new(points)
# polygon2 = Geokit::Polygon.new(points2)

# p polygon.contains? polygon.centroid
# p polygon2.contains? polygon2.centroid 




# points3 = []
# points3 << Geokit::LatLng.new(-15.7535398925005, -144.636321651707)
# points3 << Geokit::LatLng.new(-15.7474843027267, -144.650146595179)  
# points3 << Geokit::LatLng.new(-15.7367370264651, -144.655242624677)  
# points3 << Geokit::LatLng.new(-15.7286895612189, -144.65484666357 )
# points3 << Geokit::LatLng.new(-15.7224368290823, -144.650405595988)  
# points3 << Geokit::LatLng.new(-15.7189212912491, -144.644042558005)  
# points3 << Geokit::LatLng.new(-15.7181682610671, -144.638137674851)  
# points3 << Geokit::LatLng.new(-15.7201619805583, -144.631240709635)  
# points3 << Geokit::LatLng.new(-15.7235600041088, -144.626693694796)  
# points3 << Geokit::LatLng.new(-15.7352302955489, -144.622054646661)  
# points3 << Geokit::LatLng.new(-15.7414375977703, -144.62222262    )
# points3 << Geokit::LatLng.new(-15.7498000549382, -144.63043168834 )
# points3 << Geokit::LatLng.new(-15.7535398925005, -144.636321651707)


# puts
# puts
# puts
# polygon3 = Geokit::Polygon.new(points3)
# p polygon3.centroid
# p polygon3.contains? polygon3.centroid




# exit


# points = []
# points << Geokit::LatLng.new("-34.8922513", "-56.1468951")
# points << Geokit::LatLng.new("-34.905204", "-56.1848322")
# points << Geokit::LatLng.new("-34.9091105", "-56.170756")
# polygon = Geokit::Polygon.new(points)
# p polygon.contains? polygon.centroid #this should return true
		
# RGeo::Shapefile::Reader.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.shp', assume_inner_follows_outer: true) do |file|
# 	puts "File contains #{file.num_records} records."
# 	file.each do |record|
# 	  puts "Record number #{record.index}:"
# 	  puts "  Geometry: #{record.geometry.as_text}"
# 	  puts "  eco: #{record.attributes['ECO_NAME']}"
# 	end
# end

# exit


# RGeo::Shapefile::Reader.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.shp', assume_inner_follows_outer: true) do |file|
# 	puts "File contains #{file.num_records} records."
# 	file.each do |record|
# 	  puts "Record number #{record.index}:"
# 	  puts "  Geometry: #{record.geometry.as_text}"
# 	  puts "  eco: #{record.attributes['ECO_NAME']}"
	  
	 
# 		# polygons = record.geometry.as_text.tr('()MULTIPOLYGON', '').lstrip.split(', ')
# 		pp polygons
# 		exit

# 		points = []
# 		polygons.each do |polygon|
# 			x, y = polygon.split(' ')
# 			points.push(Geokit::LatLng.new(x, y))

# 		#   factory = RGeo::Cartesian::Factory
# 		#   point1 = factory.new().parse_wkt("POINT (0 0)")
# 		#   point1.within?(record.geometry)
# 		#   record.geometry
# 		end
# 		multipolygon = Geokit::Polygon.new(points)
# 		# puts multipolygon.contains? multipolygon.centroid
# 		puts multipolygon.centroid

# 		# exit
# 	end

# 		#   factory = RGeo::Cartesian::Factory
# 	#   point1 = factory.new().parse_wkt("POINT (0 0)")
# 	#   point1.within?(record.geometry)
# 	#   record.geometry
# 	# If using version 3.0.0 or earlier, rewind is necessary to return to the beginning of the file.
# 	file.rewind
# 	record = file.next

# 	points = []
# 	points << Geokit::LatLng.new("-34.8922513", "-56.1468951")
# 	points << Geokit::LatLng.new("-34.905204", "-56.1848322")
# 	points << Geokit::LatLng.new("-34.9091105", "-56.170756")
# 	polygon = Geokit::Polygon.new(points)
# 	polygon.contains? polygon.centroid #this should return true

# 	# poly_text = record.geometry.as_text #(a lot of points, I'm aware that the first point and the last one are the same, otherwise I think this wount work because needs to be a closed polygon)
# 	# factory = RGeo::Cartesian::Factory# (I'm using a cartesian factory because acording to my investigation, if I use a spheric one, this wount work)
# 	# poly = factory.new().parse_wkt(poly_text)
# 	# point1 = factory.new().parse_wkt("POINT (0 0)")# (this point does not belong to the polygon)
# 	# puts poly.within?(point1)
# 	# puts "First record geometry was: #{record.geometry.as_text}"
# end



abort 'Please use only one Taxonomy mapping strategy e.g. bundle exec ruby main.rb taxonomy -B' if (params[:taxonomy].keys.reject { |o| o == :retain || o == :synonyms_allowed }.size) > 1
## TODO: same for other options...


# ### import ncbi names do not delete should use it for later....
# conf_params = Helper.json_file_to_hash('lib/configs/ncbi_taxonomy_config.json')
# config = Config.new(conf_params)
# file_manager = config.file_manager

# ncbi_ranked_lineage_importer = NcbiRankedLineageImporter.new(file_manager: file_manager, file_name: 'rankedlineage.dmp')
# ncbi_ranked_lineage_importer.run
# ###
# exit


$areas_of, $realms_of = get_areas_of_eco_zones_and_realms


p 'woot'
fm = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
fm.create_dir
# BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: fm, filter_params: params[:filter], markers: params[:marker_objects], taxonomy_params: params[:taxonomy]).run
# NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: fm, markers: params[:marker_objects], filter_params: params[:filter], taxonomy_params: params[:taxonomy]).run
GbolJob.new(taxon: params[:taxon_object], taxonomy_params: params[:taxonomy], result_file_manager: fm, markers: params[:marker_objects], filter_params: params[:filter]).run

exit

byebug

file_manager 	= FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
bold_job 		= BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], filter_params: params[:filter], try_synonyms: true)
file_manager.create_dir
bold_job.run

exit

if params[:setup][:gbif_taxonomy]
	if Helper.new_gbif_taxonomy_available?
		puts "starting GBIF Taxonomy setup"
		gbif_taxonomy_job = GbifTaxonomyJob.new
		gbif_taxonomy_job.run
	else
		puts "GBIF Taxonomy is already up to date, do you want to replace it? [Y/n]"
		user_input  		= gets.chomp
		replace_taxonomy 	= (user_input =~ /y|yes/i) ? true : false

		if replace_taxonomy
			gbif_taxonomy_job = GbifTaxonomyJob.new
			gbif_taxonomy_job.run
		end
	end
end


if params[:setup][:ncbi_taxonomy]
	if Helper.new_ncbi_taxonomy_available?
		ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: 'lib/configs/ncbi_taxonomy_config.json')
		ncbi_taxonomy_job.run
	else
		puts "NCBI Taxonomy is already up to date, do you want to replace it? [Y/n]"
		user_input  		= gets.chomp
		replace_taxonomy 	= (user_input =~ /y|yes/i) ? true : false

		if replace_taxonomy
			ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: 'lib/configs/ncbi_taxonomy_config.json')
			ncbi_taxonomy_job.run
		end
	end
end


if params[:setup][:taxonomies]
	Helper.setup_taxonomy
end

if params[:import][:all_seqs]
	file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

	bold_job 	= BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], filter_params: params[:filter])
	genbank_job = NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], filter_params: params[:filter])
	gbol_job 	= GbolJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], file_path: Pathname.new(params[:import_gbol]), filter_params: params[:filter])

	## TODO: maybe bad, since if one Job does not work there is still the folder
	## could delte it if exit status is not 0 or some failure in between
	## catch error with begin except?
	file_manager.create_dir

	multiple_jobs = MultipleJobs.new(jobs: [gbol_job, bold_job, genbank_job])
	multiple_jobs.run

	FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Tsv)
	FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Fasta)
	FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Comparison)
end

exit

if params[:update][:all_taxonomies]
	if Helper.new_gbif_taxonomy_available?
		puts "new version of GBIF Taxonomy available, download starts soon."
		
		gbif_taxonomy_job = GbifTaxonomyJob.new
		gbif_taxonomy_job.run
	else
		puts "your GBIF Taxonomy backbone is up to date."
	end

	if Helper.new_ncbi_taxonomy_available?
		puts "new version of NCBI Taxonomy available, download starts soon."
		
		ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: 'lib/configs/ncbi_taxonomy_config.json')
		ncbi_taxonomy_job.run
	else
		puts "your NCBI Taxonomy backbone is up to date."
	end
end


exit
byebug


ncbi_taxonomy_job = NcbiTaxonomyJob.new
# ncbi_taxonomy_job.extend(constantize("Printing::#{ncbi_taxonomy_job.class}"))
ncbi_taxonomy_job.run


byebug


gbif_taxonomy_job = GbifTaxonomyJob.new
gbif_taxonomy_job.run
exit

fm = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: fm, markers: params[:marker_objects]).run
exit






# GbolJob.new.run
# exit




# DatabaseSchema.create_db
# GbifHomonymImporter.new(file_name: 'homonyms.txt').run
# exit

# byebug
if params[:import_gbol]
	gbol_importer = GbolImporter.new(fast_run: true, file_name: params[:import_gbol], query_taxon_object: params[:taxon_object])
	gbol_importer.run
	exit
elsif params[:import_genbank]
	ncbi_genbank_importer = NcbiGenbankImporter.new(fast_run: false, file_name: params[:import_genbank], query_taxon_object: params[:taxon_object], markers: params[:marker_objects]) if params[:import_genbank]
	ncbi_genbank_importer.run
	exit
elsif params[:import_bold]
	file_manager =  FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
	bold_importer = BoldImporter.new(fast_run: false, file_name: params[:import_bold], query_taxon_object: params[:taxon_object], file_manager: file_manager)
	bold_importer.run
	exit
end
exit






































ncbi_api  = NcbiApi.new(markers: params[:marker_objects], taxon_name: params[:taxon])

ncbi_api.efetch

exit



# bold_importer = BoldImporter.new(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank])
# bold_importer.run
# exit




exit

## additional opts, that the user cannot specify
## 		taxon_rank
##		taxon_record

# BoldImporter.call(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_bold]
bold_importer = BoldImporter.new(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank])
bold_importer.run

exit



NcbiGenbankJob.new(taxon: params[:taxon_record], taxonomy: GbifTaxonomy).run
exit
BoldJob.new(taxon: params[:taxon_record], taxonomy: GbifTaxonomy).run
exit





exit

job = GbifTaxonomyJob.new
job.extend(constantize("Printing::#{job.class}"))
job.run
exit

# exit


# exit






exit


exit


exit

NcbiGenbankImporter.call(file_name: params[:import_genbank], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_genbank]
exit
exit
GbolImporter.call(file_name: params[:import_gbol], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_gbol]
exit

GbolImporter.call(params[:import_gbol]) if params[:import_gbol]

exit


exit


DatabaseSchema.create_db

exit


GbifTaxonomyImporter.import(params[:import_gbif]) if params[:import_gbif]


NcbiNameImporter.import(params[:import_names]) if params[:import_names]

exit

NcbiNodeImporter.import(params[:import_nodes]) if params[:import_nodes]


exit

NcbiRankedLineageImporter.import(params[:import_lineage]) if params[:import_lineage]


exit

FtpDownloadGenbank.download if params[:download_genbank]


DatabaseSchema.create_db 								#if params[:import_fasta]

TaxRankedLineageImporter.import(params[:import_lineage]) if params[:import_lineage]
