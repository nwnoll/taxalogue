# frozen_string_literal: true

class GbolJob
    def run
        _config.file_structure.create_directory
        _config.file_manager.create_dir
        _config.downloader.new(config: _config).run
    end
  
  
    private
    def _config
        GbolConfig.new
    end
end
  