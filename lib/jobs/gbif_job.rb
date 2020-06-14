# frozen_string_literal: true

class GbifJob
    def initialize
    end
  
    def run
        _config.file_structure.create_directories
        _config.downloader.new(config: _config).run
    end
  
  
    private
    def _config
        GbifConfig.new
    end
end