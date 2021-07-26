# frozen_string_literal: true

class BoldConfig
  attr_reader :markers, :name, :parent_dir, :is_root

  DOWNLOAD_DIR = Pathname.new('downloads/BOLD/')
  
  def initialize(name:, markers: nil, parent_dir: nil, is_root: false)
    @name            = name
    @markers         = markers.kind_of?(Array) ? markers : [markers]
    @parent_dir      = parent_dir
    @is_root         = is_root
  end

  def downloader
    HttpDownloader
  end

  def address
    "http://www.boldsystems.org/index.php/API_Public/combined?taxon=#{name}&format=#{file_type}"
    
    # had to exclude markers, since if the BOLD API cant find taxon it searches for all COI-5P sequences
    # this will lead to many sequences and a crash
    # has to be filtered later on
    # "http://www.boldsystems.org/index.php/API_Public/combined?taxon=#{name}&marker=#{markers}&format=#{file_type}"

  end

  def file_type
    'tsv'
  end

  def file_structure
    FileStructure.new(config: self)
  end

  def file_manager(from_already_existing_dirs = nil)
    if is_root
      versioned_file_name = FileManager.get_versioned_file_name(name)
      versioned_file_name = from_already_existing_dirs if from_already_existing_dirs
      base_dir_path = Pathname.new("downloads/#{_source_name}/#{versioned_file_name.to_s}/")
      FileManager.new(name: name, versioning: false, base_dir: base_dir_path, config: self)
    else
      base_dir_path = Pathname.new("downloads/#{_source_name}/")
      base_dir_path = base_dir_path + parent_dir if parent_dir
      FileManager.new(name: name, versioning: false, base_dir: base_dir_path, config: self)
    end
  end

  private
  def _source_name
    self.class.to_s.gsub('Config', '').upcase
  end


  # def _join_markers(markers)
  #   markers = 'COI-5P' if markers.nil?
  #   markers.class == Array ? markers.join('|') : markers
  # end
end
