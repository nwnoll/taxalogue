# frozen_string_literal: true

class GbifTaxonJob
    def initialize
    end
  
    def run
        file_structure = _config.file_structure
        file_structure.extend(constantize("Printing::#{file_structure.class}"))
        file_structure.create_directory

        downloader = _config.downloader.new(config: _config)
        downloader.extend(constantize("Printing::#{downloader.class}"))
        downloader.run

        _config.importers.each do |importer_class|
            importer = importer_class.new(file_name: _config.file_structure.file_path)
            importer.extend(constantize("Printing::#{importer.class}"))
            importer.run
        end
    end
  
  
    private
    def _config
        GbifTaxonConfig.new
    end
end