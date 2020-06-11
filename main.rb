# frozen_string_literal: true

require "bundler"
require "active_record"
require "sqlite3"
require 'bio'
require 'fuzzystringmatch'

require "yaml"
require 'optparse'
require 'json'
require 'pp'
require 'open-uri'
require 'net/ftp'
require 'net/http'
require_relative "db/database_schema"

Bundler.require

sections = ['services', 'models', 'importer', 'jobs', 'downloader', 'config']
sections.each do |section|
	Dir[File.dirname(__FILE__) + "/lib/#{section}/*.rb"].each do |file|
		# puts File.basename(file, File.extname(file))
		require_relative "lib/#{section}/#{File.basename(file, File.extname(file))}"
	end
end

params = {}
OptionParser.new do |opts|
  opts.on('-i FASTA', 	String, '--import_fasta')
  opts.on('-l LINEAGE', String, '--import_lineage')
  opts.on('-g GBOL', 	String, '--import_gbol')
  opts.on('-o BOLD', 	String, '--import_bold')
  opts.on('-k GENBANK', String, '--import_genbank')
  opts.on('-f GBIF', 	String, '--import_gbif')
  opts.on('-n NODES', 	String, '--import_nodes')
  opts.on('-a NAMES', 	String, '--import_names')
  opts.on('-t TAXON', 	String, '--taxon')
  opts.on('-d', 				'--download_genbank')
end.parse!(into: params)

Bundler.require

db_config_file 	= File.open("db/database.yaml")
db_config 		= YAML::load(db_config_file)

ActiveRecord::Base.establish_connection(db_config)

if params[:taxon]
	taxon_name = params[:taxon]
	record = GbifTaxon.find_by_canonical_name(taxon_name)
	if record
		params[:taxon_rank] = record.taxon_rank
	else
		exit 'Cannot find Taxon, please only use Kingdom, Phylum, Class, Order, Family or Genus'
	end
else
	params[:taxon] = 'Arthropoda'
	record = GbifTaxon.find_by_canonical_name(params[:taxon])
	params[:taxon_rank] = record.taxon_rank
end

BoldJob.new(taxon: 'Lentulidae', taxonomy: GbifTaxon).run

exit

NcbiGenbankImporter.call(file_name: params[:import_genbank], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_genbank]
exit
BoldImporter.call(file_name: params[:import_bold], query_taxon: params[:taxon], query_taxon_rank: params[:taxon_rank]) if params[:import_bold]
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
