# frozen_string_literal: true

class MidoriConfig
    attr_reader :name, :releases

    DOWNLOAD_DIR = Pathname.new("downloads/MIDORI/")
    RELEASES = { 
        :current    => 'MIDORI_GB260',
        :previous   => []
    }
    def initialize()
        @name = 'MIDORI_GB260'
    end
  
    def downloader
        HttpDownloader
    end
  
    def address
        "https://www.reference-midori.info/download/Databases/GenBank260_2024-04-15/RAW/uniq/MIDORI2_UNIQ_NUC_GB260_CO1_RAW.fasta.gz"
    end

    def file_type
        'gz'
    end

    def file_manager
        FileManager.new(name: name, versioning: false, base_dir: "downloads/#{_source_name}/", config: self)
    end
  
    def _join_markers(markers)
        markers = 'COI-5P' if markers.nil?
        markers.class == Array ? markers.join('|') : markers
    end

    private
    def _source_name
      self.class.to_s.gsub('Config', '').upcase
    end
  end
  
