# frozen_string_literal: true

class GbolConfig
    attr_reader :name
    def initialize()
        @name            = 'GBOL_Dataset_Release-20210128'
    end
  
    def downloader
        HttpDownloader
    end
  
    def address
        ## does not work anymore :(
        'https://www.bolgermany.de/gbol1/release/GBOL_Dataset_Release-20210128.zip'

        ## other possible slution is to build a crawler and cut out sequence data :
        # https://collections.zfmk.de/specimendetail/656103
        # 
    end

    def file_type
        'zip'
        # ## TODO: change back to zip
        # 'csv'
    end

    def file_manager
        FileManager.new(name: name, versioning: false, base_dir: "fm_data/#{_source_name}/", config: self)
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
  