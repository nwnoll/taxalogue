# frozen_string_literal: true

class BoldConfig
  attr_reader :markers, :file_structure, :name, :parent_dir
  def initialize(name:, markers: nil, parent_dir: nil)
    @name            = name
    @markers         = markers.kind_of?(Array) ? markers : [markers]
    @parent_dir      = parent_dir
    @file_structure  = file_structure
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

  # def _join_markers(markers)
  #   markers = 'COI-5P' if markers.nil?
  #   markers.class == Array ? markers.join('|') : markers
  # end
end
