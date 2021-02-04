# frozen_string_literal: true

require './requirements'

params = {}
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

OptionParser.new do |opts|
	opts.on('-i FASTA', 	String, '--import_fasta')
	opts.on('-g GBOL', 	String, '--import_gbol')
	opts.on('-o BOLD', 	String, '--import_bold')
	opts.on('-k GENBANK', 	String, '--import_genbank')
	opts.on('-b GBIF', 	String, '--import_gbif')
	opts.on('-n NODES', 	String, '--import_nodes')
	opts.on('-a NAMES', 	String, '--import_names')
	opts.on('-l LINEAGE', 	String, '--import_lineage')
	opts.on('-d', 			  '--download_genbank')
	opts.on('-t TAXON', 	String, '--taxon') do |taxon_name|

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

	opts.on('-s', '--import_all_seqs') 
	opts.on('-x', '--setup_taxonomy')
	opts.on('-c', '--setup_ncbi_taxonomy')
	opts.on('-y', '--setup_gbif_taxonomy')
	opts.on('-u', '--update_taxonomy')
	opts.on('-f [FILTER]', String, '--filter') do |filter_params|
		if filter_params.nil?
			puts "No arguments provided, will use the following:"
			puts "No N allowed"
			puts "No Gaps allowed"
			puts "Minimum Length is 300 and the maximum Length is 1000"
			
			# default:
			extracted_filter_params = Helper.extract_filter_params("N0,G0,L300-1000")
		else
			unless filter_params.match?(/[NnGg\-Ll]/)
				abort "invalid arguments, use it for example like this: --filter N0,G0,L300-1000\narguments are separated by a comma and no spaces are alllowed."
			end

			extracted_filter_params = Helper.extract_filter_params(filter_params)
			unless extracted_filter_params
				abort "invalid arguments, use it for example like this: --filter N0,G0,L300-1000\narguments are separated by a comma and no spaces are alllowed."
			end		
		end
		extracted_filter_params
	end
	
end.parse!(into: params)


pp params

fm = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
fm.create_dir
# BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: fm, filter_params: params[:filter], markers: params[:marker_objects]).run
# NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: fm, markers: params[:marker_objects], filter_params: params[:filter]).run
GbolJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: fm, markers: params[:marker_objects], filter_params: params[:filter]).run

exit

byebug

file_manager 	= FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
bold_job 		= BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxonomy, result_file_manager: file_manager, markers: params[:marker_objects], filter_params: params[:filter], try_synonyms: true)
file_manager.create_dir
bold_job.run

exit

if params[:setup_gbif_taxonomy]
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


if params[:setup_ncbi_taxonomy]
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


if params[:setup_taxonomy]
	Helper.setup_taxonomy
end

if params[:import_all_seqs]
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

if params[:update_taxonomy]
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
