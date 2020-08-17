# frozen_string_literal: true

class FileStructure
  private
  attr_reader :config

  public
  def initialize(config:)
    @config = config
  end

  def create_directory
    FileUtils.mkdir_p directory_path unless _directory_exists?
  end

  def file_path
    "#{directory_path}#{_name}.#{config.file_type}"
  end

  def directory_path
    _parent_dir ? "data/#{_source_name}/#{_parent_dir}/#{_name}/" : "data/#{_source_name}/#{_name}/"
  end

  private
  def _source_name
    config.class.to_s.gsub('Config', '').downcase
  end

  def _parent_dir
    config.parent_dir
  end

  def _name
    config.name
  end

  def _directory_exists?
    File.directory?(directory_path)
  end
end
