# frozen_string_literal: true

require "bundler"
require "active_record"
require "sqlite3"
require 'bio'
require 'fuzzystringmatch'
require 'zip'
require 'tree'
require 'parallel'
require 'pastel'
require 'countries'
require 'shp'

require "yaml"
require 'optparse'
require 'json'
require 'pp'
require 'open-uri'
require 'net/ftp'
require 'net/http'
require 'csv'
require 'fileutils'
require 'pathname'
require 'ostruct'
require 'timeout'
require 'digest/md5'
require 'digest/bubblebabble'
require 'time'
require 'rexml/document'
require 'biodiversity'

require_relative ".db/database_schema"
require_relative '.lib/output_formats/output_format'

sections = ['helpers', 'decorators', 'services', 'models', 'importers', 'classifiers', 'jobs', 'downloaders', 'configs', 'output_formats']
sections.each do |section|
	Dir[File.dirname(__FILE__) + "/.lib/#{section}/*.rb"].each do |file|
		# puts File.basename(file, File.extname(file))
		require_relative ".lib/#{section}/#{File.basename(file, File.extname(file))}"
	end
end

Bundler.require

mode = ENV['TAXALOGUE_MODE']
mode = 'production' if mode.nil?

db_config_file 	= File.open(".db/database.yaml")
db_config 		= YAML::load(db_config_file)

if File.exists?(db_config[mode]['database'])
	ActiveRecord::Base.establish_connection(db_config[mode])
else
    state = TaxonomyHelper.download_predefined_database
    
    if state == :success
        ActiveRecord::Base.establish_connection(db_config[mode])
    else
        ActiveRecord::Base.establish_connection(db_config[mode])
	    DatabaseSchema.create_db
    end
end

database_tables = [
    :ncbi_ranked_lineages,
    :ncbi_names,
    :ncbi_nodes,
    :gbif_taxonomy,
    :gbif_homonyms,
    :sequences,
    :taxon_object_proxies,
    :sequence_taxon_object_proxies
]

DatabaseSchema.create_db if database_tables.any? { |table| ActiveRecord::Base.connection.table_exists?(table) == false }

if mode == 'production'
    unless GbifTaxonomy.any?
        puts "GBIF Taxonomy is not setup yet, downloading and importing GBIF Taxonomy, this may take a while."
        
        gbif_taxonomy_job = GbifTaxonomyJob.new
        gbif_taxonomy_job.run
    end

    unless NcbiRankedLineage.any? || NcbiName.any? || NcbiNode.any? 
        puts "NCBI Taxonomy is not setup yet, downloading and importing NCBI Taxonomy, this may take a while."
        
        ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
        ncbi_taxonomy_job.run
    end

    unless GbifHomonym.any?
        state = TaxonHelper.import_homonyms
        ## retry
        TaxonHelper.import_homonyms if state == :no_file
    end
end