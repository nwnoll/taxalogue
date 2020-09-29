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

require_relative "db/database_schema"
require_relative 'lib/helpers/helper'
require_relative 'lib/output_formats/output_format'

Bundler.require

sections = ['decorators', 'services', 'models', 'importers', 'jobs', 'downloaders', 'configs', 'output_formats']
sections.each do |section|
	Dir[File.dirname(__FILE__) + "/lib/#{section}/*.rb"].each do |file|
		# puts File.basename(file, File.extname(file))
		require_relative "lib/#{section}/#{File.basename(file, File.extname(file))}"
	end
end

db_config_file 	= File.open("db/database.yaml")
db_config 		= YAML::load(db_config_file)

ActiveRecord::Base.establish_connection(db_config)