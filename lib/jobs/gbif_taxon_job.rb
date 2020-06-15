# frozen_string_literal: true

class GbifTaxonJob
    def initialize
    end
  
    def run
        fs = _config.file_structure
        fs.extend(constantize("Printing::#{fs.class}"))
        fs.create_directories

        dl = _config.downloader.new(config: _config)
        dl.extend(constantize("Printing::#{dl.class}"))
        dl.run

        # exit
        # importer = _config.importer.new(file_name: _config.file_structure.file_path)
        # importer.extend(Printing)
        
    end
  
  
    private
    def _config
        GbifTaxonConfig.new
    end
end