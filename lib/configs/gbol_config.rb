# frozen_string_literal: true

class GbolConfig
    attr_reader :file_structure, :taxon_name
    def initialize()
        @file_structure  = file_structure
        @taxon_name      = 'GBOL_Dataset_Release-20200426'
    end
  
    def downloader
        HttpDownloader
    end
  
    def address
        'https://bolgermany.de/release/GBOL_Dataset_Release-20200426.zip'
    end

    def file_type
        'zip'
    end
  
    def file_structure
        FileStructure.new(config: self)
    end
  
    def _join_markers(markers)
        markers = 'COI-5P' if markers.nil?
        markers.class == Array ? markers.join('|') : markers
    end
  end
  