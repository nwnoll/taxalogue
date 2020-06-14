# frozen_string_literal: true

class GbifConfig
    attr_reader :file_structure, :name
    def initialize()
        @file_structure  = file_structure
        @name            = 'backbone'
    end
  
    def downloader
        HttpDownloader
    end
  
    def address
        'https://hosted-datasets.gbif.org/datasets/backbone/backbone-current.zip'
    end

    def file_type
        'zip'
    end
  
    def file_structure
        FileStructure.new(config: self)
    end
  end
  