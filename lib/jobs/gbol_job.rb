# frozen_string_literal: true

class GbolJob
    attr_reader :taxon_name
    def initialize()
        @taxon_name = 'all'
    end
  
    def run
        _config.file_structure.create_directories
        _config.downloader.new(config: _config).run
    end
  
  
    private
    def _config
        GbolConfig.new
    end
end
  