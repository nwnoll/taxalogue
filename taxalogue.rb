# frozen_string_literal: true

require './.requirements'
include GeoUtils

params = {
    download: Hash.new,
    classify: Hash.new,
    setup: Hash.new,
    update: Hash.new,
    filter: Hash.new,
    derep: Hash.new,
    taxonomy: Hash.new,
    region: Hash.new,
    output: Hash.new
}

$fada_regions_of    = Hash.new
$eco_zones_of       = Hash.new
$continent_of       = Hash.new
$custom_regions_of  = Hash.new

CONFIG_FILE = 'default_config.yaml'

if File.exist? CONFIG_FILE
    config_options = YAML.load_file(CONFIG_FILE)
    params.merge!(config_options)
    
    taxon_object = TaxonHelper.get_taxon_record(params)
    if taxon_object.nil?
        abort "Cannot find default Taxon, please only use Kingdom, Phylum, Class, Order, Family, Genus or Species\nMaybe the Taxonomy Database is not properly setup, run the program with --setup_taxonomy to fix the issue."
    end

    params[:taxon_object]   = taxon_object
    params[:marker_objects] = MiscHelper.create_marker_objects(query_marker_names: params[:markers])
end

## modified after https://gist.github.com/rkumar/445735
subtext = <<HELP
Commonly used subcommands are:
   download :  downloads sequence and specimen data
   classify :  normalizes the taxon names based on used taxonomy
   setup    :  setup taxonomies
   update   :  update taxonomies 
   filter   :  set filter options
   derep    :  remove sequences that have the exact same sequence of characters and length
   taxonomy :  different options regarding the used taxonomy
   region   :  select sequences by country, continent, biogeographic regions etc.
   output   :  specify different output formats

See 'bundle exec ruby taxalogue.rb SUBCOMMAND --help' for more information on a specific subcommand.

HELP


global = OptionParser.new do |opts|
    #opts.banner = "\nUsage: bundle exec ruby taxalogue.rb [subcommand [params]]"
    opts.banner = "\nUsage: bundle exec ruby taxalogue.rb [params] [subcommand [params]]"
    opts.on('-t TAXON', String, '--taxon', 'Choose a taxon to build your database, if you want a database for a species, put "" around the option: e.g.: -t "Apis mellifera". default: Arthropoda') do |taxon_name|
        abort 'Taxon is extinct, please choose another Taxon' if TaxonHelper.is_extinct?(taxon_name)
        params[:taxon] = taxon_name
        taxon_name
    end
	
    opts.on('-m MARKERS', String, '--markers', 'Currently only co1 is available. default: co1') do |markers|
        params[:marker_objects] = MiscHelper.create_marker_objects(query_marker_names: markers)
    end

    opts.on('-f FAST_RUN', FalseClass, '--fast_run', 'Accellerates Taxon comparison. Turn it on with --fast_run true. default: false') do |flag|
        params[:fast_run] = flag
        flag
    end

    opts.on('-n NUM_THREADS', Integer, '--num_threads', 'Number of threads for downloads. default: 5') do |num_threads|
        params[:num_threads] = num_threads
        num_threads
    end

    opts.on('-c NUM_CORES', Integer, '--num_cores', 'Number of cores used. default: 5') do |num_cores|
        params[:num_cores] = num_cores
        num_cores
    end

    opts.on('-v', '--version', 'Shows the used version of taxalogue') do |version|
        params[:version] = true
        version
    end

    opts.on('-r', '--citation', 'How to cite taxalogue') do |citation|
        params[:citation] = true
        citation
    end


    opts.separator ""
    opts.separator subtext
end


subcommands = {

    download: OptionParser.new do |opts|
        opts.banner = "Usage: download [options]"
      	opts.on('-a', '--all', 'Download records from BOLD, GenBank and GBOL')
      	opts.on('-g', '--gbol', 'Download records from GBOL')
      	opts.on('-o', '--bold', 'Download records from BOLD')
      	opts.on('-k', '--genbank', 'Download records from GenBank')
      	opts.on('-m', '--midori', 'Download records from MIDORI')
      	opts.on('-G GBOL_DIR', String, '--gbol_dir', 'Path of GBOL directory that should be checked for failures. The failed downloads will be downloaded again.') do |opt|
            Pathname.new(opt)
        end
        opts.on('-B BOLD_DIR', String, '--bold_dir', 'Path of BOLD directory that should be checked for failures. The failed downloads will be downloaded again.') do |opt|
            Pathname.new(opt)
        end
      	opts.on('-K GENBANK_DIR', String, '--genbank_dir', 'Path of GenBank directory that should be checked for failures. The failed downloads will be downloaded again.') do |opt|
            Pathname.new(opt)
        end
      	opts.on('-i', '--inv_contaminants', 'Download possible invertebrate contaminants')
    end,

    classify: OptionParser.new do |opts|
        opts.banner = "Usage: classify [options]"
      	opts.on('-a', '--all', 'Latest downloads of all source databases will be classified')
      	opts.on('-g', '--gbol', 'Latest download of GBOL database will be classified')
      	opts.on('-b', '--bold', 'Latest download of BOLD database will be classified')
      	opts.on('-k', '--genbank', 'Latest download of NCBI GenBank database will be classified')
        opts.on('-m', '--midori', 'Latest download MIDORI  will be classified')
        opts.on('-r BOLD_RELEASE', String, '--bold_release', 'Specify the .tsv from the BOLD release file.') { |opt| Pathname.new(opt) }
      	opts.on('-G GBOL_DIR', String, '--gbol_dir', 'Specify the GBOL directory that should be classified')
      	opts.on('-B BOLD_DIR', String, '--bold_dir', 'Specify the BOLD directory that should be classified')
      	opts.on('-K GENBANK_DIR', String, '--genbank_dir', 'Specify the NCBI GenBank directory that should be classified')
        opts.on('-M MIDORI', String, '--midori_dir', 'Specify the .gz file from the downloads/MIDORI folder') { |opt| Pathname.new(opt) }
      	opts.on('-n', '--no_merge', 'results are not merged')
    end,

    setup: OptionParser.new do |opts|
        opts.banner = "Usage: setup [options]"
	opts.on('-n', '--ncbi_taxonomy', 'Setup the NCBI Taxonomy database')
	opts.on('-g', '--gbif_taxonomy', 'Setup the GBIF Taxonomy database')
	opts.on('-h', '--gbif_homonyms', 'Add GBIF Homonyms to the database')
	opts.on('-x', '--reset_taxonomies', 'Destroy the old taxonomy database and creates a complete new one. includes: [--ncbi_taxonomy, --gbif_taxonomy, --gbif_homonyms]')
    end,

    update: OptionParser.new do |opts|
        opts.banner = "Usage: update [options]"
        opts.on('-a', '--all')
	opts.on('-b', '--gbif_taxonomy')
        opts.on('-n', '--ncbi_taxonomy')
        opts.on('-B', '--check_gbif_taxonomy', 'Checks if a new GBIF Taxonomy backbone is available')
        opts.on('-N', '--check_ncbi_taxonomy', 'Checks if a new NCBI Taxonomy backbone is available')
        opts.on('-m', '--midori_config', 'Updates taxalogue, so that it is able to download the newest MIDORI release')
        opts.on('-g', '--gbol_config', 'Updates taxalogue, so that it is able to download the newest GBOL release')
    end,

    output: OptionParser.new do |opts|
        opts.banner = "Usage: output [options]"
        opts.on('-t BOOLEAN', TrueClass, '--table',          'TSV Table. default: true') {}
        opts.on('-f BOOLEAN', TrueClass, '--fasta',          'fasta file. default: true')
        opts.on('-c BOOLEAN', TrueClass, '--comparison',     'Comparison TSV, shows initial Taxon information and harmonization by Taxonomy. default: true')
        opts.on('-q BOOLEAN', FalseClass, '--qiime2',         'QIIME2 Taxonomy files, includes a taxonomy text file and a fasta file.')
        opts.on('-k BOOLEAN', FalseClass, '--kraken2',        'Kraken2 fasta file, works only with NCBI taxonomy.')
        opts.on('-d BOOLEAN', FalseClass, '--dada2_taxonomy', 'Fasta output file for the dada2 assignTaxonomy function.')
        opts.on('-s BOOLEAN', FalseClass, '--dada2_species',  'Fasta output file for the dada2 assignSpecies function')
        opts.on('-x BOOLEAN', FalseClass, '--sintax',         'Fasta output file for the SINTAX program')
    end,

    filter: OptionParser.new do |opts|
        opts.banner = "Usage: filter [options]"
        opts.on('-N MAX_N', Integer, '--max_N')
        opts.on('-G MAX_GAPS', Integer,'--max_G')
        opts.on('-l MIN_LENGTH', Integer,'--min_length')
        opts.on('-L MAX_LENGTH', Integer,'--max_length')
        opts.on('-r TAXON_RANK', String,'--taxon_rank', 'Filter for minimal taxon rank. e.g --taxon_rank genus considers sequences with at least genus information, therefore only sequences with species or genus information are considered. Allowed values: species, genus, family, order, class, phylum, kingdom') do |opt|
            unless GbifTaxonomy.possible_ranks.include?(opt)
                puts "#{opt} is not allowed for: filter --taxon_rank"
                puts "Please use one of the following:"
                pp GbifTaxonomy.possible_ranks
                puts

                exit
            end

            opt
        end
    end,

    derep: OptionParser.new do |opts|
        opts.banner = "Usage: derep [options]"
        opts.on('-l', '--last_common_ancestor', 'If some taxonomic assignments have for example the same number of associated specimens or ar e from the same taxonomic rank, the last common ancestor is chosen.') do |opt|
            params[:derep][:random]     = false
            params[:derep][:discard]    = false
            params[:derep][:no_derep]   = false

            opt
        end

        opts.on('-r', '--random', 'If some taxonomic assignments for a given sequence have the same precedence, the candidate is chosen in input order') do |opt|
            params[:derep][:last_common_ancestor]   = false
            params[:derep][:discard]                = false
            params[:derep][:no_derep]               = false

            opt
        end

        opts.on('-d', '--discard', 'If some taxonomic assignments for a given sequence have the same precedence, the sequence is discarded.') do |opt|
            params[:derep][:last_common_ancestor]   = false
            params[:derep][:random]                 = false
            params[:derep][:no_derep]               = false

            opt
        end

        opts.on('-n', '--no_derep', 'Turn dereplication off; default: true') do |opt|
            params[:derep][:last_common_ancestor]   = false
            params[:derep][:random]                 = false
            params[:derep][:discard]                = false

            opt
        end
    
    end,

    taxonomy: OptionParser.new do |opts|
        opts.banner = "Usage: taxonomy [options]"
	opts.on('-B', '--gbif', 'Taxon information is mapped to GBIF Taxonomy backbone') do |opt|
	    params[:taxonomy][:ncbi] = false
	    params[:taxonomy][:unmapped] = false
            opt
	end
        opts.on('-n', '--ncbi', 'Taxon information is mapped to NCBI Taxonomy; default: true') do |opt|
	    params[:taxonomy][:gbif] = false
	    params[:taxonomy][:unmapped] = false
            opt
	end
	opts.on('-u', '--unmapped', 'No mapping takes place, original specimen information is used but only standard ranks are used (e.g. no subfamilies)') do |opt|
            params[:taxonomy][:gbif] = false
            params[:taxonomy][:ncbi] = false
            opt
        end
        opts.on('-s', '--synonyms_allowed', 'Allows Taxon information of synonyms to be set to sequences')
        opts.on('-r', '--retain', 'retains sequences for taxa that are not present in chosen taxonomy')
	end,

	region: OptionParser.new do |opts|
	    opts.set_summary_width 50
            $continent_of = get_continent_of_country_hash
	    opts.banner = "Usage: region [options]"
	    opts.on('-c COUNTRY', String, '--country', 'create a database consisting of sequences only from this country or a set of countries: if you want to specifiy multiple countries please use semicolons without spaces and quotes e.g. "Germany;France;Belgium"') do |opt|
	        valid_names = all_country_names 
		opt_ary = opt.split(';')
		RegionHelper.check_valid_names(valid_names, opt_ary)
		params[:region][:country_ary] = opt_ary
		opt
	    end
	    opts.on('-C', '--available_countries', 'lists all available countries') { RegionHelper.print_all_countries; exit }
	    opts.on('-k CONTINENT', String,'--continent', 'create a database consisting of sequences only from this continent or a set of continents: if you want to specifiy a continent please use quotes e.g. "North America". For multiple continents please use semicolons without spaces e.g. "Europe;Asia"') do |opt|
	        valid_names = all_continent_names
	        opt_ary = opt.split(';')
	        RegionHelper.check_valid_names(valid_names, opt_ary)
	        params[:region][:continent_ary] = opt_ary
	        opt
	    end
	    opts.on('-K', '--available_continents', 'lists all available continents') { RegionHelper.print_all_continents; exit }
	    opts.on('-b BIOGEOGRAPHIC_REALM', String,'--biogeographic_realm', 'create a database consisting of sequences only from this biogegraphic realm or a set of realms: if you want to specifiy a realm please use quotes e.g. "Oriental (Indomalaya)". For multiple realms pleas use quotes and semicolons without spaces e.g."Oriental (Indomalaya);Afrotropical"') do |opt|
	        params = RegionHelper.check_biogeo(params)
	        if params[:region][:biogeo_ary] == :skip
                    opt
	        else
                    valid_names = $fada_regions_of.keys.sort
	            opt_ary = opt.split(';')
	            RegionHelper.check_valid_names(valid_names, opt_ary)
	            params[:region][:biogeo_ary] = opt_ary
	            opt
                end
            end
	    opts.on('-B', '--available_biogeographic_realms', 'lists all available biogeographic realms') do |opt|
	        params = RegionHelper.check_biogeo(params)
	        if params[:region][:biogeo_ary] == :skip
		    exit
		else
		    RegionHelper.print_all_regions($fada_regions_of.keys.sort)
		    exit
		end
	    end
            opts.on('-e TERRESTRIAL_ECOREGION', String, '--terrestrial_ecoregion', 'create a database consisting of sequences only from this terrestrial ecoregion or a set of regions: if you want to specifiy a region please use quotes e.g. "North Atlantic moist mixed forests". For multiple realms pleas use quotes and semicolons without spaces e.g."North Atlantic moist mixed forests;Highveld grasslands"') do |opt|
                params = RegionHelper.check_fada(params)
		if params[:region][:terreco_ary] == :skip
                    opt
		else
		    valid_names = $eco_zones_of.keys.sort
		    opt_ary = opt.split(';')
		    RegionHelper.check_valid_names(valid_names, opt_ary)
		    params[:region][:terreco_ary] = opt_ary
                    opt
		end
	    end
            opts.on('-E', '--available_terrestrial_ecoregion', 'lists all available terrestrial ecoregions') do |opt|
            params = RegionHelper.check_fada(params)
	    if params[:region][:terreco_ary] == :skip
                exit
	    else
                RegionHelper.print_all_regions($eco_zones_of.keys.sort)
	        exit
	    end
        end
        opts.on('-s CUSTOM_SHAPEFILE', String, '--custom_shapefile', 'Provide the path of the custom shapefile (only the *.shp is needed here, .shx and .dbf are inferred, and need to be in the same folder), has to be used with the -S option to provide the attribute name that should be used')
        opts.on('-S CUSTOM_SHAPEFILE_ATTRIBUTE', String, '--custom_shapefile_attribute', 'Provide the wanted attribute in shapefile, has to be used with the -s option to specify the according shape file')
        opts.on('-v CUSTOM_SHAPEFILE_VALUES', String, '--custom_shapefile_values', 'create a database consisting of sequences only from regions with the specified value: if you want to specifiy a region please use quotes e.g. "North Atlantic moist mixed forests". For multiple realms pleas use quotes and semicolons without spaces e.g."North Atlantic moist mixed forests;Highveld grasslands"')
    end
}
global.order!

loop do 
    break if ARGV.empty?

    command = ARGV.shift.to_sym
    subcommands[command].order!(into: params[command]) unless subcommands[command].nil?
end

if MiscHelper.multiple_actions?(params)
    puts "You specified more than one action"
    puts "Never use download, classify or setup simultaneously"
    puts
    puts "download is used to only download sequences without classifying"
    puts "e.g: bundle exec ruby taxalogue.rb -t Trichoptera download --all"
    puts
    puts "classify is used to only classify already downloaded sequences"
    puts "e.g: bundle exec ruby taxalogue.rb -t Trichoptera download --all filter -N 5 taxonomy --gbif"
    puts
    puts "setup is used to setup the taxonomy database"
    puts "e.g: bundle exec ruby taxalogue.rb setup --ncbi_taxonomy"
    puts
    puts "update is used to check if a new Taxonomy release is available and to set it up"
    puts "e.g: bundle exec ruby taxalogue.rb update --ncbi_taxonomy"
    puts
    exit
end

if params[:output][:kraken2] && !params[:taxonomy][:ncbi]
    puts "The Kraken2 Output requires the NCBI Taxonomy"
    puts "Any other Taxonomy is not allowed"
    puts
    
    exit
end

if params[:output][:dada2_species] && !(params[:filter][:taxon_rank] == 'species' || params[:filter][:taxon_rank].nil?) 
    puts "The dada2 species output requires species information"
    puts "Therefore your filter --taxon_rank value is not allowed"
    puts
    
    exit
end

set_custom_shapefile_params_count = MiscHelper.custom_shapefile_params_count(params)
if set_custom_shapefile_params_count > 0 && set_custom_shapefile_params_count != 3
    puts "If a custom shape file should be used, you need to specify these 3 parameters:"
    puts "--custom_shapefile"
    puts "--custom_shapefile_attribute"
    puts "--custom_shapefile_values"
    puts
    puts 'e.g.:'
    puts 'bundle exec ruby taxalogue.rb region --custom_shapefile downloads/SHAPEFILES/fada_regions/fadaregions.shp --custom_shapefile_attribute name --custom_shapefile_values "Nearctic;Palaearctic"'
    puts
    
    exit
elsif set_custom_shapefile_params_count == 3
    RegionHelper.use_custom_shapefile(params)
end
# bundle exec ruby taxalogue.rb region -s downloads/SHAPEFILES/fada_regions/fadaregions.shp -S name -v "Nearctic;Palaearctic"

if params[:derep].values.count(true) > 1
    puts "Only one dereplication strategy is allowed"
    
    exit
end
$params = params # Need to initialize it already here since I use the global in the next statement 


if params[:download].any? && DerepHelper.do_derep 
    params[:derep].keys.each { |key| params[:derep][key] = false unless key == :no_derep }
end
$params = params # Needs to be updated after every change

## TODO: maybe I have to prevent classify, etc if this is done...
params[:download][:bold]    = true if params[:download][:bold_dir]
params[:download][:gbol]    = true if params[:download][:gbol_dir]
params[:download][:genbank] = true if params[:download][:genbank_dir]
$params = params # Needs to be updated after every change

if params[:version]
    puts 'taxalogue v1.1.0'
    
    exit
end

if params[:citation]
    puts 'Noll NW, Scherber C, Schäffler L. 2023. taxalogue: a toolkit to create comprehensive CO1 reference databases. PeerJ 11:e16253 https://doi.org/10.7717/peerj.16253' 
    
    exit
end

## if taxonomy was chosen by user, it needs to be updated
## object is also not set in opts.on
params = TaxonHelper.assign_taxon_info_to_params(params, params[:taxon])
MiscHelper.print_params(params)


$params = params


if params[:download].any?
    jobs = []
    file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

    params[:download].each do |key, value|
        if key == :all && params[:download][key]
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(ncbi_genbank_job, gbol_job, bold_job)
        end

        if key == :bold && jobs.none? { |e| e.class == BoldJob } && params[:download][key]
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(bold_job)
        end

        if key == :gbol && jobs.none? { |e| e.class == GbolJob } && params[:download][key]
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(gbol_job)
        end

        if key == :genbank && jobs.none? { |e| e.class == NcbiGenbankJob } && params[:download][key]
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            
            jobs.push(ncbi_genbank_job)
        end

        if key == :midori && jobs.none? { |e| e.class == MidoriJob } && params[:download][key]
            midori_job = MidoriJob.new(params: params, result_file_manager: file_manager)
            
            jobs.push(midori_job)
        end
    end

    multiple_jobs = MultipleJobs.new(jobs: jobs, params: params)
	multiple_jobs.run
    sleep 2

    exit
end


## TODO rename classify
if params[:classify].any?
    jobs = []
    file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

    params[:classify].each do |key, value|
        if key == :all && params[:classify][key]
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(ncbi_genbank_job, gbol_job, bold_job)
        end

        if (key == :bold || key == :bold_dir || key == :bold_release) && jobs.none? { |e| e.class == BoldJob }  && params[:classify][key]
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(bold_job)
        end

        if (key == :gbol || key == :gbol_dir) && jobs.none? { |e| e.class == GbolJob } && params[:classify][key]
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(gbol_job)
        end

        if (key == :genbank || key == :genbank_dir) && jobs.none? { |e| e.class == NcbiGenbankJob } && params[:classify][key]
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            
            jobs.push(ncbi_genbank_job)
        end

        if (key == :midori || key == :midori_dir) && jobs.none? { |e| e.class == MidoriJob } && params[:classify][key]
            midori_job = MidoriJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(midori_job)
        end
    end

    file_manager.create_dir

    multiple_jobs = MultipleJobs.new(jobs: jobs, params: params)
    jobs_state = multiple_jobs.run
    sleep 2

    ## TODO: why dont create marshal files etc if no_merge?
    unless params[:classify][:no_merge]
        if jobs_state == :success
            puts
            puts 'merging output files, this might take a while'
            MiscHelper.run_file_merger(file_manager: file_manager, params: params)
            MiscHelper.write_marshal_file(dir: file_manager.dir_path, file_name: '.params.dump', data: params)
            
            file = File.open(file_manager.dir_path + 'taxalogue.txt', 'w')
            MiscHelper.print_params(params, file)
            puts 'finished'
        end
    end

    exit
end


if params[:setup].any?
    params[:setup].each do |key, value|
        if key == :reset_taxonomies && params[:setup][key]
            MiscHelper.OUT_question("Do you really want to reset? This will destroy the taxonomy database and recreate it. [Y/n]")
            
            user_input  = gets.chomp
            reset_db = (user_input =~ /y|yes/i) ? true : false
        
            if reset_db
                FileUtils.rm('.db/database.db') if File.file?('.db/database.db')
        
                db_config_file 	= File.open(".db/database.yaml")
                db_config 		= YAML::load(db_config_file)
                ActiveRecord::Base.establish_connection(db_config['production'])
                DatabaseSchema.create_db
        
                MiscHelper.OUT_header("Downloading and importing GBIF Taxonomy")
                puts
                gbif_taxonomy_job = GbifTaxonomyJob.new
                gbif_taxonomy_job.run
                puts "imported GBIF Taxonomy"
                puts
        
                MiscHelper.OUT_header("Downloading and importing NCBI Taxonomy")
                puts
                ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
                ncbi_taxonomy_job.run
                puts "imported NCBI Taxonomy"
                puts
        
                MiscHelper.OUT_header("Downloading and importing GBIF Homonyms")
                puts
                TaxonHelper.import_homonyms
        
                puts "imported GBIF Homonyms"
                puts
            end

            exit
        end

        if key == :ncbi_taxonomy && params[:setup][key]
            MiscHelper.OUT_header("Downloading and importing NCBI Taxonomy")
            puts
            ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
            ncbi_taxonomy_job.run
            puts "imported NCBI Taxonomy"
            puts
        end

        if key == :gbif_taxonomy && params[:setup][key]
            MiscHelper.OUT_header("Downloading and importing GBIF Taxonomy")
            puts
            gbif_taxonomy_job = GbifTaxonomyJob.new
            gbif_taxonomy_job.run
            puts "imported GBIF Taxonomy"
            puts
        end

        if key == :gbif_homonyms && params[:setup][key]
            MiscHelper.OUT_header("Downloading and importing GBIF Homonyms")
            puts
            TaxonHelper.import_homonyms
    
            puts "imported GBIF Homonyms"
            puts
        end
    end
end


if params[:update].any?
    if params[:update][:all]
        params[:update][:ncbi_taxonomy] = true
        params[:update][:gbif_taxonomy] = true
    end

    params[:update].each do |key, value|
        if key == :gbif_taxonomy && params[:update][key]
            MiscHelper.OUT_header("Checking if a new GBIF Taxonomy backbone is available")
            puts
            
            is_available = TaxonomyHelper.new_gbif_taxonomy_available?

            if is_available
                puts 'Found new GBIF Taxonomy backbone'
                puts

                MiscHelper.OUT_header("Downloading and importing GBIF Taxonomy")
                puts
                gbif_taxonomy_job = GbifTaxonomyJob.new
                gbif_taxonomy_job.run
                puts "imported GBIF Taxonomy"
                puts
            else
                puts 'Not found'
                puts
            end
        end

        if key == :ncbi_taxonomy && params[:update][key]
            MiscHelper.OUT_header("Checking if a new NCBI Taxonomy is available")
            puts
            
            is_available = TaxonomyHelper.new_ncbi_taxonomy_available?

            if is_available
                puts 'Found new NCBI Taxonomy backbone'
                puts

                MiscHelper.OUT_header("Downloading and importing NCBI Taxonomy")
                puts
                gbif_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
                gbif_taxonomy_job.run
                puts "imported NCBI Taxonomy"
                puts
            else
                puts 'Not found'
                puts
            end
        end

        if key == :midori_config && params[:update][key]
            MiscHelper.OUT_header("Updating MIDORI Config")
            HttpDownloader2.new(address: 'https://raw.githubusercontent.com/nwnoll/taxalogue/master/.lib/configs/midori_config.rb', destination: '.lib/configs/midori_config.rb').run
            puts 'finished'
        end

        if key == :gbol_config && params[:update][key]
            MiscHelper.OUT_header("Updating GBOL Config")
            HttpDownloader2.new(address: 'https://raw.githubusercontent.com/nwnoll/taxalogue/master/.lib/configs/gbol_config.rb', destination: '.lib/configs/gbol_config.rb').run
            puts 'finished'
        end
    end

end
