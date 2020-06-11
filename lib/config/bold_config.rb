# frozen_string_literal: true

class BoldConfig
  attr_reader :taxon, :markers, :file_structure
  def initialize(taxon:, markers: nil)
    @taxon           = taxon
    @markers         = _join_markers(markers)
    @file_structure  = file_structure
  end

  def downloader
    HttpDownloader
  end

  def address
    "http://www.boldsystems.org/index.php/API_Public/combined?taxon=#{taxon}&marker=#{markers}&format=tsv"
  end

  def file_structure
    FileStructure.new(config: self)
  end

  def _join_markers(markers)
    markers = 'COI-5P' if markers.nil?
    markers.class == Array ? markers.join('|') : markers
  end
end
