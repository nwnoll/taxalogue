# frozen_string_literal: true

require './.requirements'
include GeoUtils

params = {
	create: Hash.new,
    download: Hash.new,
	classify: Hash.new,
	import: Hash.new,
    merge: Hash.new,
	setup: Hash.new,
	update: Hash.new,
	filter: Hash.new,
	derep: Hash.new,
	taxonomy: Hash.new,
	region: Hash.new,
    output: Hash.new
}

$fada_regions_of 	= Hash.new
$eco_zones_of 		= Hash.new
$continent_of 		= Hash.new

CONFIG_FILE = 'default_config.yaml'

if File.exists? CONFIG_FILE
	config_options = YAML.load_file(CONFIG_FILE)
	params.merge!(config_options)

	taxon_object = TaxonHelper.get_taxon_record(params)
	
	if taxon_object.nil?
		abort "Cannot find default Taxon, please only use Kingdom, Phylum, Class, Order, Family, Genus or Species\nMaybe the Taxonomy Database is not properly setup, run the program with --setup_taxonomy to fix the issue."
	end

	params[:taxon_object] 	= taxon_object
	params[:marker_objects] = MiscHelper.create_marker_objects(query_marker_names: params[:markers])
end

## modified after https://gist.github.com/rkumar/445735
subtext = <<HELP
Commonly used commands are:
   create   :  creates a barcode database
   download :  downloads sequence and specimen data
   classify :  normalizes the taxon names based on used taxonomy
   merge    :  combines results from different source databases
   setup    :  setup Taxonomies
   update   :  update taxonomies or sequences
   filter   :  filter sequences
   derep    :  Remove sequences that have the exact same sequence of characters and length
   taxonomy :  different options regarding the used taxonomy
   region   :  select sequences by country, continent, biogeographic regions etc.
   import   :  imports files into SQL database, in general this happens after first start automatically
   output   :  specify different output formats

See 'bundle exec ruby taxalogue.rb COMMAND --help' for more information on a specific command.

HELP

global = OptionParser.new do |opts|
	opts.banner = "\nUsage: bundle exec ruby taxalogue.rb [params] [subcommand [params]]"
	opts.on('-t TAXON', String, '--taxon', 'Choose a taxon to build your database, if you want a database for a species, put "" around the option: e.g.: -t "Apis mellifera". default: Arthropoda') do |taxon_name|
		abort 'Taxon is extinct, please choose another Taxon' if TaxonHelper.is_extinct?(taxon_name)

		# params = TaxonHelper.assign_taxon_info_to_params(params, taxon_name)
		params[:taxon] = taxon_name
		taxon_name
	end
	
	opts.on('-m MARKERS', String, '--markers', 'Currently only co1 is available. default: co1') do |markers|
		params[:marker_objects] = MiscHelper.create_marker_objects(query_marker_names: markers)
	end

    opts.on('-f FAST_RUN', TrueClass, '--fast_run', 'Accellerates Taxon comparison. Turn it off with --fast_run false. default: true') do |flag|
        params[:fast_run] = flag
        flag
    end

    opts.on('-n NUM_THREADS', Integer, '--num_threads', 'Number of threads for downloads. default: 5') do |num_threads|
        params[:num_threads] = num_threads
        num_threads
    end
  
  opts.separator ""
  opts.separator subtext
end

subcommands = { 
	create: OptionParser.new do |opts|
		opts.banner = "Usage: create [options]"
		opts.on('-a', '--all', 'creates a reference database with sequences from BOLD, GenBank and GBOL')
		opts.on('-g', '--gbol', 'creates a reference database with sequences from GBOL')
		opts.on('-b', '--bold', 'creates a reference database with sequences from BOLD')
		opts.on('-k', '--genbank', 'creates a reference database with sequences from Genbank')
		opts.on('-C', '--no_contaminants', 'If set, then no possible contaminants are downloaded. Some sequences in the source databases have wrong labels and belong in fact to theses contaminants.')
	end,

    download: OptionParser.new do |opts|
		opts.banner = "Usage: download [options]"
		opts.on('-g', '--gbol')
		opts.on('-o', '--bold')
		opts.on('-k', '--genbank')
		opts.on('-a', '--all')
		opts.on('-i', '--inv_contaminants', 'Download possible invertebrate contaminants')
   	end,

	classify: OptionParser.new do |opts|
		opts.banner = "Usage: classify [options]"
		opts.on('-a', '--all', 'Latest downloads of all source databases will be classified')
		opts.on('-g', '--gbol', 'Latest download of GBOL database will be classified')
		opts.on('-b', '--bold', 'Latest download of BOLD database will be classified')
		opts.on('-k', '--genbank', 'Latest download of NCBI GenBank database will be classified')
		opts.on('-G GBOL_DIR', String, '--gbol_dir', 'Specify the GBOL directory that should be classified')
		opts.on('-B BOLD_DIR', String, '--bold_dir', 'Specify the BOLD directory that should be classified')
		opts.on('-K GENBANK_DIR', String, '--genbank_dir', 'Specify the NCBI GenBank directory that should be classified')
		opts.on('-M', '--no_merge', 'results are not merged')
	end,

    merge: OptionParser.new do |opts|
        opts.banner = "Usage: merge [options]"
        opts.on('-d RESULT_DIR', String, '--result_dir', 'Result directory that should be merged')
        opts.on('-a', '--all', 'Merges output of all source databases')
        opts.on('-g', '--gbol', 'Merges output of GBOL source database')
        opts.on('-b', '--bold', 'Merges output of BOLD source database')
        opts.on('-k', '--genbank', 'Merges output of NCBI GenBank source database')
    end,

    output: OptionParser.new do |opts|
        opts.banner = "Usage: output [options]"
        opts.on('-t BOOLEAN', TrueClass, '--table', 'TSV Table. default: true')
        opts.on('-f BOOLEAN', TrueClass, '--fasta', 'fasta file. default: true')
        opts.on('-c BOOLEAN', TrueClass, '--comparison', 'Comparison TSV, shows initial Taxon information and normalization by Taxonomy. default: true')
        opts.on('-q BOOLEAN', FalseClass, '--qiime2', 'QIIME2 Taxonomy files, includes a taxonomy text file and a fasta file.')
        opts.on('-k BOOLEAN', FalseClass, '--kraken2', 'Kraken2 fasta file, works only with NCBI taxonomy.')
        opts.on('-d BOOLEAN', FalseClass, '--dada2_taxonomy', 'Fasta output file for the dada2 assignTaxonomy function.')
        opts.on('-s BOOLEAN', FalseClass, '--dada2_species', 'Fasta output file for the dada2 assignSpecies function')
    end,

	import: OptionParser.new do |opts|
		opts.banner = "Usage: import [options]"
		opts.on('-g GBIF', String, '--gbif')
		opts.on('-n NCBI_NODES', String, '--nodes')
		opts.on('-s NCBI_NAMES', String, '--names')
		opts.on('-l NCBI_LINEAGE', String, '--lineage')
   	end,

   	setup: OptionParser.new do |opts|
		opts.banner = "Usage: setup [options]"
		opts.on('-t', '--taxonomies')
		opts.on('-n', '--ncbi_taxonomy')
		opts.on('-g', '--gbif_taxonomy')
		opts.on('-r', '--regions')
		opts.on('-e', '--terrestrial_ecoregions')
		opts.on('-b', '--biogeographic_realms')
   	end,

   	# update: OptionParser.new do |opts|
	# 	opts.banner = "Usage: update [options]"
	# 	opts.on('-A', '--all_taxonomies')
	# 	opts.on('-b', '--gbif_taxonomy')
	# 	opts.on('-n', '--ncbi_taxonomy')
	# 	opts.on('-a', '--all_sequences')
	# 	opts.on('-o', '--bold_sequences')
	# 	opts.on('-k', '--genbank_sequences')
	# 	opts.on('-g', '--gbol_sequences')
	# end,

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
        opts.on('-l BOOLEAN', TrueClass, '--last_common_ancestor', 'If some taxonomic assignments have for example the same number of associated specimens or ar e from the same taxonomic rank, the last common ancestor is chosen. default: true') do |opt|
            params[:derep][:random]     = false
            params[:derep][:discard]    = false

            opt
        end
        opts.on('-r BOOLEAN', TrueClass, '--random', 'If some taxonomic assignments for a given sequence have the same precedence, the candidate is chosen in input order') do |opt|
            params[:derep][:last_common_ancestor]   = false
            params[:derep][:discard]                = false

            opt
        end
        opts.on('-d BOOLEAN', TrueClass, '--discard', 'If some taxonomic assignments for a given sequence have the same precedence, the sequence is discarded.') do |opt|
            params[:derep][:last_common_ancestor]   = false
            params[:derep][:random]                 = false

            opt
        end
    
    end,

	taxonomy: OptionParser.new do |opts|
		opts.banner = "Usage: taxonomy [options]"
		opts.on('-b', '--gbif', 'Taxon information is mapped to GBIF Taxonomy backbone + additional available datasets from the GBIF API') do |opt|
			params[:taxonomy][:gbif_backbone] = false
			params[:taxonomy][:ncbi] = false

			opt
		end
		opts.on('-B', '--gbif_backbone', 'Taxon information is mapped to GBIF Taxonomy backbone') do |opt|
			params[:taxonomy][:gbif] = false
			params[:taxonomy][:ncbi] = false

			opt
		end
		opts.on('-n', '--ncbi', 'Taxon information is mapped to NCBI Taxonomy') do |opt|
			params[:taxonomy][:gbif_backbone] = false
			params[:taxonomy][:gbif] = false

			opt
		end
		opts.on('-u', '--unmapped', 'No mapping takes place, original specimen information is used but only standard ranks are used (e.g. no subfamilies)')
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
		opts.on('-e TERRESTRIAL_ECOREGION', String,'--terrestrial_ecoregion', 'create a database consisting of sequences only from this terrestrial ecoregion or a set of regions: if you want to specifiy a region please use quotes e.g. "North Atlantic moist mixed forests". For multiple realms pleas use quotes and semicolons without spaces e.g."North Atlantic moist mixed forests;Highveld grasslands"') do |opt|
			
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
    puts "Never use create, download, or classify simultaneously"
    puts
    puts "create is used to download and classify at the same time"
    puts "e.g: bundle exec ruby taxalogue.rb -t Trichoptera create --all filter -N 5"
    puts
    puts "download is used to only download sequences without classifying"
    puts "e.g: bundle exec ruby taxalogue.rb -t Trichoptera download --all"
    puts
    puts "classify is used to only classify already downloaded sequences"
    puts "e.g: bundle exec ruby taxalogue.rb -t Trichoptera download --all filter -N 5 taxonomy --gbif_backbone"
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

if params[:derep].values.count(true) > 1
    puts "Only one derep strategy is allowed"

    exit
end

if params[:merge].any? && params[:derep].any? { |opt| opt.last == true }
    puts "Merging while dereplicating is not possibble at the moment"
    puts "Only merging will be executed"

    params[:derep].each { |param| param = false }
end

## if taxonomy was chosen by user, it needs to be updated
## object is also not set in opts.on
params = TaxonHelper.assign_taxon_info_to_params(params, params[:taxon])

MiscHelper.print_params(params)

if params[:derep].any? { |opt| opt.last == true }
    DatabaseSchema.drop(:sequence_taxon_object_proxies) if ActiveRecord::Base.connection.table_exists?(:sequence_taxon_object_proxies)
    DatabaseSchema.create_table(:sequence_taxon_object_proxies)
end

if params[:create].any?
    jobs = []
    file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

    params[:create].each do |key, value|
        if key == :all
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(ncbi_genbank_job, gbol_job, bold_job)
        end

        if key == :bold && jobs.none? { |e| e.class == BoldJob }
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(bold_job)
        end

        if key == :gbol && jobs.none? { |e| e.class == GbolJob }
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(gbol_job)
        end

        if key == :genbank && jobs.none? { |e| e.class == NcbiGenbankJob }
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            
            jobs.push(ncbi_genbank_job)
        end
    end

    abort MiscHelper.OUT_error "Need at least one parameter for the databases: e.g: create --all" if jobs.empty?

    file_manager.create_dir
	
    multiple_jobs = MultipleJobs.new(jobs: jobs, params: params)
    MiscHelper.get_inv_contaminants(file_manager, params[:marker_objects]) unless params[:create][:no_contaminants]

	jobs_state = multiple_jobs.run
    sleep 2

    if jobs_state == :success
        MiscHelper.run_file_merger(file_manager: file_manager, params: params)
        MiscHelper.write_marshal_file(dir: file_manager.dir_path, file_name: '.params.dump', data: params)
    
        file = File.open(file_manager.dir_path + 'taxalogue.txt', 'w')
        MiscHelper.print_params(params, file)
    end

    exit
end


if params[:download].any?
    jobs = []
    file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

    params[:download].each do |key, value|
        if key == :all
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(ncbi_genbank_job, gbol_job, bold_job)
        end

        if key == :bold && jobs.none? { |e| e.class == BoldJob }
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(bold_job)
        end

        if key == :gbol && jobs.none? { |e| e.class == GbolJob }
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(gbol_job)
        end

        if key == :genbank && jobs.none? { |e| e.class == NcbiGenbankJob }
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            
            jobs.push(ncbi_genbank_job)
        end
    end

    multiple_jobs = MultipleJobs.new(jobs: jobs, params: params)
	multiple_jobs.run
    sleep 2

    exit
end


if params[:classify].any?
    jobs = []
    file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

    params[:classify].each do |key, value|
        if key == :all
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(ncbi_genbank_job, gbol_job, bold_job)
        end

        if (key == :bold || key == :bold_dir) && jobs.none? { |e| e.class == BoldJob }
            bold_job = BoldJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(bold_job)
        end

        if (key == :gbol || key == :gbol_dir) && jobs.none? { |e| e.class == GbolJob }
            gbol_job = GbolJob.new(result_file_manager: file_manager, params: params)
            
            jobs.push(gbol_job)
        end

        if (key == :genbank || key == :genbank_dir) && jobs.none? { |e| e.class == NcbiGenbankJob }
            ncbi_genbank_job = NcbiGenbankJob.new(params: params, result_file_manager: file_manager)
            
            jobs.push(ncbi_genbank_job)
        end
    end

    file_manager.create_dir

    multiple_jobs = MultipleJobs.new(jobs: jobs, params: params)
	jobs_state = multiple_jobs.run
    sleep 2

    ## TODO: why dont create marshal files etc if no_merge?
    unless params[:classify][:no_merge]
        if jobs_state == :success
            MiscHelper.run_file_merger(file_manager: file_manager, params: params)
            MiscHelper.write_marshal_file(dir: file_manager.dir_path, file_name: '.params.dump', data: params)
            
            file = File.open(file_manager.dir_path + 'taxalogue.txt', 'w')
            MiscHelper.print_params(params, file)
        end
    end

    exit
end

if params[:merge].any?
    if params[:merge][:result_dir].nil?
        puts "Need a result directory:"
        puts "please specify it with merge --result_dir DIRECTORY_PATH"
        puts

        exit
    end

    result_file_manager_from_dir_path = Pathname.new(params[:merge][:result_dir]) + '.result_file_manager.dump'
    
    begin
        result_file_manager_from_dir = DownloadCheckHelper.get_object_from_marshal_file(result_file_manager_from_dir_path)
    rescue StandardError => e
        puts "Result directory can't be used, please specify another one"
        puts

        exit
    end

    file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)

    source_db_keywords = []
    params[:merge].each do |key, value|
        source_db_keywords.push('ncbi_', 'gbol_', 'bold_') if key == :all
        source_db_keywords.push('bold_') if key == :bold && source_db_keywords.none? { |e| e == '_bold_' }
        source_db_keywords.push('gbol_') if key == :gbol && source_db_keywords.none? { |e| e == '_gbol_' }
        source_db_keywords.push('ncbi_') if key == :genbank && source_db_keywords.none? { |e| e == '_ncbi_' }
    end

    selected_source_db_files = result_file_manager_from_dir.created_files.select do |e|
        is_match = false
        source_db_keywords.each do |keyword|
            
            if e.path.basename.to_s.match?(keyword)
                is_match = true
                break
            end
        end
        
        is_match
    end

    file_manager.created_files = selected_source_db_files
    file_manager.create_dir

    MiscHelper.run_file_merger(file_manager: file_manager, params: params)
    
    all_files_from_old_dir = result_file_manager_from_dir.all_and_hidden_dir_path_files

    download_info_files = all_files_from_old_dir.select do |e|
        is_match = false
        source_db_keywords.each do |keyword|
            if e.basename.to_s.match?(/^\.?#{keyword}/)
                is_match = true

                break
            end
        end
        
        is_match
    end

    download_info_files.each do |download_info_file|
        next unless download_info_file.basename.to_s.starts_with?('.')
        
        file = File.read(download_info_file)
        file =~ /^\s{6}(.*?);/
        dir = $1
        dir_path = Pathname.new(dir)
        
        if download_info_file.basename.to_s.starts_with?('.bold_')
            DownloadCheckHelper.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir: dir_path, result_file_manager: file_manager, source: BoldJob)
        elsif download_info_file.basename.to_s.starts_with?('.gbol_')
            DownloadCheckHelper.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir: dir_path, result_file_manager: file_manager, source: GbolJob)
        elsif download_info_file.basename.to_s.starts_with?('.ncbi_')
            DownloadCheckHelper.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir: dir_path, result_file_manager: file_manager, source: NcbiGenbankJob)
        end
    end

    file_manager.copy_files(download_info_files)
    MiscHelper.write_marshal_file(dir: file_manager.dir_path, file_name: '.params.dump', data: params)
    
    file = File.open(file_manager.dir_path + 'taxalogue.txt', 'w')
    MiscHelper.print_params(params, file)

    puts MiscHelper.OUT_header "Output locations:"
    puts MiscHelper.OUT_success file_manager.dir_path

    exit
end

## TODO:
## NEXT:
# gbchg dvision plus accession of changed seq
# gbdel dvision plus accession of deleted seq
# num of seqs and bases is i relase note
# gbrel.txt relase notes of current
# num of new files per division
# 1.3.1 Organizational changes

#   The total number of sequence data files increased by 91 with this release:
  
#   - the BCT division is now composed of 533 files (+21)
#   - the CON division is now composed of 219 files (+1)
#   - the ENV division is now composed of  63 files (+1)
#   - the INV division is now composed of 132 files (+35)
#   - the PAT division is now composed of 217 files (+4)
#   - the PLN division is now composed of 605 files (+11)
#   - the VRL division is now composed of  45 files (+1)
#   - the VRT division is now composed of 231 files (+17)

# gbnew.txt division plus accession of added seq

# one strategy
# download whole new release..
# another
# go to chng del and new and only download the ones listed
# if i only use the listed should i copy the old ones?
# or just use them from the old release?+
# makes things way mor complicated
# but saves download time


## another thing is the scanning of division files, sometimes only 3 records are in it. most likely not cox1..
# dont knwo if i have to read in the whole file anyway?


exit

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

	# if shp_obj.get_x_min.positive? && shp_obj.get_y_min.positive?
	# 	$splitted_areas_of[:positive_x][:positive_y][eco_name]
	# end

	field_num_of.each do |field, num|
	end
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
	# 	$areas_of[name].each do |area|
	# 		if area.contains?(Geokit::LatLng.new(47.997791, 7.842609))
	# 			print '  '
	# 		end
	# 	end
	# end

	# shape_objects.each do |o| 
	# 	o.get_x.size.times do |i|
	# 		is_in_polygon = rect_polygon.contains?(Geokit::LatLng.new(o.get_x[i], o.get_y[i]))
	# 	end
	# end
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
# 	file.each do |record|
# 	end
# end

# exit


# RGeo::Shapefile::Reader.open('/home/nnoll/bioinformatics/wwf_eco/wwf_terr_ecos.shp', assume_inner_follows_outer: true) do |file|
# 	file.each do |record|
	  
	 
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
# end



# abort 'Please use only one Taxonomy mapping strategy e.g. bundle exec ruby taxalogue.rb taxonomy -B' if (params[:taxonomy].keys.reject { |o| o == :retain || o == :synonyms_allowed }.size) > 1
## TODO: same for other options...


# ### import ncbi names do not delete should use it for later....
# conf_params = MiscHelper.json_file_to_hash('.lib/configs/ncbi_taxonomy_config.json')
# config = Config.new(conf_params)
# file_manager = config.file_manager

# ncbi_ranked_lineage_importer = NcbiRankedLineageImporter.new(file_manager: file_manager, file_name: 'rankedlineage.dmp')
# ncbi_ranked_lineage_importer.run
# ###
# exit


$areas_of, $realms_of = get_areas_of_eco_zones_and_realms


exit

byebug

file_manager 	= FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
bold_job 		= BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], filter_params: params[:filter], try_synonyms: true)
file_manager.create_dir
bold_job.run

exit

if params[:setup][:gbif_taxonomy]
	if TaxonomyHelper.new_gbif_taxonomy_available?
		gbif_taxonomy_job = GbifTaxonomyJob.new
		gbif_taxonomy_job.run
	else
		user_input  		= gets.chomp
		replace_taxonomy 	= (user_input =~ /y|yes/i) ? true : false

		if replace_taxonomy
			gbif_taxonomy_job = GbifTaxonomyJob.new
			gbif_taxonomy_job.run
		end
	end
end


if params[:setup][:ncbi_taxonomy]
	if TaxonomyHelper.new_ncbi_taxonomy_available?
		ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
		ncbi_taxonomy_job.run
	else
		user_input  		= gets.chomp
		replace_taxonomy 	= (user_input =~ /y|yes/i) ? true : false

		if replace_taxonomy
			ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
			ncbi_taxonomy_job.run
		end
	end
end


if params[:setup][:taxonomies]
	TaxonomyHelper.setup_taxonomy
end

if params[:setup][:terrestrial_ecoregions]
	RegionHelper.get_shape_terreco_regions
end

if params[:setup][:biogeographic_realms]
	RegionHelper.get_shape_fada_regions
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
	if TaxonomyHelper.new_gbif_taxonomy_available?
		
		gbif_taxonomy_job = GbifTaxonomyJob.new
		gbif_taxonomy_job.run
	else
	end

	if TaxonomyHelper.new_ncbi_taxonomy_available?
		
		ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
		ncbi_taxonomy_job.run
	else
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






































ncbi_api  = NcbiApi.new(markers: params[:marker_objects], taxon_name: params[:taxon])

ncbi_api.efetch

exit



# bold_classifier = BoldClassifier.new(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank])
# bold_classifier.run
# exit




exit

## additional opts, that the user cannot specify
## 		taxon_rank
##		taxon_record

# BoldClassifier.call(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_bold]
bold_classifier = BoldClassifier.new(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank])
bold_classifier.run

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

NcbiGenbankClassifier.call(file_name: params[:import_genbank], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_genbank]
exit
exit
GbolClassifier.call(file_name: params[:import_gbol], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_gbol]
exit

GbolClassifier.call(params[:import_gbol]) if params[:import_gbol]

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