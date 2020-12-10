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
require 'time'

require_relative "db/database_schema"
require_relative 'lib/helpers/helper'
require_relative 'lib/output_formats/output_format'

Bundler.require

db_config_file 	= File.open("db/database.yaml")
db_config 		= YAML::load(db_config_file)

if File.exists?(db_config['database'])
	ActiveRecord::Base.establish_connection(db_config)
else
	ActiveRecord::Base.establish_connection(db_config)
	DatabaseSchema.create_db
end

sections = ['decorators', 'services', 'models', 'importers', 'jobs', 'downloaders', 'configs', 'output_formats']
sections.each do |section|
	Dir[File.dirname(__FILE__) + "/lib/#{section}/*.rb"].each do |file|
		# puts File.basename(file, File.extname(file))
		require_relative "lib/#{section}/#{File.basename(file, File.extname(file))}"
	end
end

unless GbifTaxonomy.any? 
	gbif_taxonomy_job = GbifTaxonomyJob.new
	gbif_taxonomy_job.run
end

unless NcbiRankedLineage.any? || NcbiName.any? || NcbiNode.any?
	ncbi_taxonomy_job = NcbiTaxonomyJob.new
	ncbi_taxonomy_job.run
end
