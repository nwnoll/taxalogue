# frozen_string_literal: true

class NcbiGenbankConfig
  attr_reader :name, :markers, :file_manager, :use_http
  def initialize(name:, markers: nil, use_http: false)
    @name             = name
    @markers          = markers
    @file_manager     = _file_manager
    @use_http         = use_http
  end

  def downloader
    use_http ? HttpDownloader : FtpDownloader
  end

  def address
    'ftp.ncbi.nlm.nih.gov'
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

  private
  def _source_name
    self.class.to_s.gsub('Config', '').upcase
  end

  def _file_manager
    FileManager.new(name: name, versioning: false, base_dir: "fm_data/#{_source_name}/", config: self, multiple_files_per_dir: true)
  end

end
