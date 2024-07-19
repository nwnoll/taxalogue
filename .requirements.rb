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
#require 'biodiversity'

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
require 'set'

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


if File.exist?(db_config[mode]['database'])
    $db_connection = ActiveRecord::Base.establish_connection(db_config[mode])
    if mode == 'test'
        DatabaseSchema.destroy_whole_db(db_config[mode]['database'])
        DatabaseSchema.create_db
    end
else
    $db_connection = ActiveRecord::Base.establish_connection(db_config[mode])
    DatabaseSchema.create_db
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
        MiscHelper.OUT_header("GBIF Taxonomy is not setup yet, downloading and importing GBIF Taxonomy, this may take a while.")
        puts

        gbif_taxonomy_job = GbifTaxonomyJob.new
        gbif_taxonomy_job.run

        puts 'GBIF Taxonomy has been imported'
        puts
    end

    unless NcbiRankedLineage.any? || NcbiName.any? || NcbiNode.any? 
        MiscHelper.OUT_header("NCBI Taxonomy is not setup yet, downloading and importing NCBI Taxonomy, this may take a while.")
        puts

        ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: '.lib/configs/ncbi_taxonomy_config.json')
        ncbi_taxonomy_job.run

        puts 'NCBI Taxonomy has been imported'
        puts
    end

    unless GbifHomonym.any?
        MiscHelper.OUT_header("Homonyms are not setup yet, downloading and importing homonyms.")
        puts

        state = TaxonHelper.import_homonyms
        ## retry
        if state == :no_file
            MiscHelper.OUT_error("Homonyms could not be imported")
            puts
            puts 'retry'
            state = TaxonHelper.import_homonyms
            if state == :no_file
                MiscHelper.OUT_error("Homonyms could not be imported")
                puts
                puts 'Please try again later with bundle exec ruby taxalogue.rb setup --gbif_homonyms'
                puts
            else
                puts 'Homonyms have been imported'
                puts
            end
        else
            puts 'Homonyms have been imported'
            puts
        end
    end
end
