# frozen_string_literal: true

class NcbiConfig
  attr_reader :taxon_name, :markers, :file_structure
  def initialize(taxon_name:, markers: nil)
    @taxon_name      = taxon_name
    @markers         = markers
    @file_structure  = file_structure
  end

  def downloader
    FtpDownloader
  end

  def address
    'ftp.ncbi.nlm.nih.gov'
  end

  def file_structure
    FileStructure.new(config: self)
  end
end
