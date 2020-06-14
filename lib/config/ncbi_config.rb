# frozen_string_literal: true

class NcbiConfig
  attr_reader :taxon, :divisions, :markers, :file_structure
  def initialize(taxon:, markers: nil, file_structure:)
    @taxon           = taxon
    @divisions       = divisions
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

  def divisions
    params[:ncbi_divisions] = NcbiDivision.get_id(taxon_name: taxon.canonical_name)
		params[:ncbi_divisions] = [1, 2, 5, 6, 10] if taxon.canonical_name  == 'Animalia'
  end
end
