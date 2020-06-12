# frozen_string_literal: true

class NcbiConfig
  attr_reader :taxon, :divisions, :file_structure
  def initialize(taxon:, divisions:)
    @taxon           = taxon
    @divisions       = divisions
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
