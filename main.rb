# frozen_string_literal: true

require './requirements'

params = {}
CONFIG_FILE = 'default_config.yaml'

if File.exists? CONFIG_FILE
	config_options = YAML.load_file(CONFIG_FILE)
	params.merge!(config_options)
	params[:taxon_object] = GbifTaxon.find_by_canonical_name(params[:taxon])
	params[:marker_objects] = Helper.create_marker_objects(query_marker_names: params[:markers])
end


OptionParser.new do |opts|
	opts.on('-i FASTA', 	String, '--import_fasta')
	opts.on('-g GBOL', 	String, '--import_gbol')
	opts.on('-o BOLD', 	String, '--import_bold')
	opts.on('-k GENBANK', 	String, '--import_genbank')
	opts.on('-f GBIF', 	String, '--import_gbif')
	opts.on('-n NODES', 	String, '--import_nodes')
	opts.on('-a NAMES', 	String, '--import_names')
	opts.on('-d', 			  '--download_genbank')
	opts.on('-t TAXON', 	String, '--taxon') do |taxon_name|

		## TODO: should be changed, maybe
		taxon_objects 	= GbifTaxon.where(canonical_name: taxon_name)
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
	opts.on('-s', '--import_all') 
end.parse!(into: params)


if params[:import_all]
	file_manager = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
	
	bold_job 	= BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxon, result_file_manager: file_manager)
	genbank_job = NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxon, result_file_manager: file_manager, markers: params[:marker_objects])
	gbol_job 	= GbolJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxon, result_file_manager: file_manager, markers: params[:marker_objects], file_path: Pathname.new(params[:import_gbol]))

	multiple_jobs = MultipleJobs.new(jobs: [gbol_job, bold_job, genbank_job], file_manager: file_manager)
	multiple_jobs.run
end

byebug


gbif_taxon_job = GbifTaxonJob.new
gbif_taxon_job.run
exit

fm = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
NcbiGenbankJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxon, result_file_manager: fm, markers: params[:marker_objects]).run
exit


fm = FileManager.new(name: params[:taxon_object].canonical_name, versioning: true, base_dir: 'results', force: true, multiple_files_per_dir: true)
BoldJob.new(taxon: params[:taxon_object], taxonomy: GbifTaxon, result_file_manager: fm).run
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



NcbiGenbankJob.new(taxon: params[:taxon_record], taxonomy: GbifTaxon).run
exit
BoldJob.new(taxon: params[:taxon_record], taxonomy: GbifTaxon).run
exit



ncbi_taxonomy_job = NcbiTaxonomyJob.new
ncbi_taxonomy_job.extend(constantize("Printing::#{ncbi_taxonomy_job.class}"))
ncbi_taxonomy_job.run

exit

job = GbifTaxonJob.new
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


GbifTaxonImporter.import(params[:import_gbif]) if params[:import_gbif]


NcbiNameImporter.import(params[:import_names]) if params[:import_names]

exit

NcbiNodeImporter.import(params[:import_nodes]) if params[:import_nodes]


exit

NcbiRankedLineageImporter.import(params[:import_lineage]) if params[:import_lineage]


exit

FtpDownloadGenbank.download if params[:download_genbank]


DatabaseSchema.create_db 								#if params[:import_fasta]

TaxRankedLineageImporter.import(params[:import_lineage]) if params[:import_lineage]
