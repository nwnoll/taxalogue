# frozen_string_literal: true
require 'fileutils'

class FileStructure
  private
  attr_reader :config

  public
  def initialize(config:)
    @config = config
  end

  def create_directories
    FileUtils.mkdir_p directory_path unless _directory_exists?
  end

  def file_path
    "#{directory_path}#{_taxon_name}.tsv"
  end

  def directory_path
    "data/#{_source_name}/#{_taxon_name}/"
  end

  private
  def _source_name
    config.class.to_s.gsub('Config', '').downcase
  end

  def _taxon_name
    config.taxon_name
  end

  def _directory_exists?
    File.directory?(file_path)
  end
end
