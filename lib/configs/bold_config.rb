# frozen_string_literal: true

class BoldConfig
  attr_reader :markers, :file_structure, :name
  def initialize(name:, markers: nil)
    @name            = name
    @markers         = _join_markers(markers)
    @file_structure  = file_structure
  end

  def downloader
    HttpDownloader
  end

  def address
    "http://www.boldsystems.org/index.php/API_Public/combined?taxon=#{name}&marker=#{markers}&format=#{file_type}"
  end

  def file_type
    'tsv'
  end

  def file_structure
    FileStructure.new(config: self)
  end

  def _join_markers(markers)
    markers = 'COI-5P' if markers.nil?
    markers.class == Array ? markers.join('|') : markers
  end
end
