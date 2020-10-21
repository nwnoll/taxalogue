# frozen_string_literal: true

class NcbiGenbankConfig
  attr_reader :name, :markers, :file_structure
  def initialize(name:, markers: nil)
    @name            = name
    @markers         = markers
    @file_structure  = file_structure
  end

  def downloader
    FtpDownloader
  end

  def address
    'ftp.ncbi.nlm.nih.gov'
  end

  def file_manager
    FileManager.new(name: name, versioning: false, base_dir: 'fm_data/', config: self)
  end

  def file_structure
    FileStructure.new(config: self)
  end

  def target_directory
    'genbank'
  end

  def target_file_base
    "gb#{name}"
  end

  def file_type
    'seq.gz'
  end
end
