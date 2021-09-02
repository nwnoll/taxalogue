# frozen_string_literal: true

class NcbiGenbankConfig
    attr_reader :name, :markers, :file_manager, :use_http, :parent_dir

    DOWNLOAD_DIR = Pathname.new("downloads/NCBIGENBANK/")
    CURRENT_RELEASE_ADDRESS = 'https://ftp.ncbi.nlm.nih.gov/genbank/GB_Release_Number'

    def initialize(name:, markers: nil, use_http: false, parent_dir:)
        @name             = name
        @markers          = markers
        @parent_dir       = parent_dir
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
        # if is_root
            FileManager.new(name: name, versioning: false, base_dir: DOWNLOAD_DIR + parent_dir, config: self, multiple_files_per_dir: true)
        # else
            # FileManager.new(name: name, versioning: false, base_dir: DOWNLOAD_DIR + parent_dir, config: self, multiple_files_per_dir: true)
        # end
    end

end
