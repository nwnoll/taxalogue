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
    FileUtils.mkdir_p _directory_path unless _directory_exists?
  end

  def file_path
    "#{_directory_path}/#{config.taxon}.tsv"
  end

  private

  def _directory_path
    "data/#{_source_name}/#{_taxon_name}"
  end

  def _source_name
    config.class.to_s.gsub('Config', '').downcase
  end

  def _taxon_name
    config.taxon
  end

  def _directory_exists?
    File.directory?(file_path)
  end
end
