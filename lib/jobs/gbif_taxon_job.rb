# frozen_string_literal: true

class GbifTaxonJob
    def initialize
    end
  
    def run
        file_manager = _config.file_manager
        file_manager.create_dir

        # downloader = _config.downloader.new(config: _config)
        # downloader.extend(Helper.constantize("Printing::#{downloader.class}"))
        # downloader.run

        _config.importers.each do |importer_name, import_file|
            importer_class  = Helper.constantize(importer_name)
            importer        = importer_class.new(file_manager: _config.file_manager, file_name: import_file)
            # importer.extend(Helper.constantize("Printing::#{importer_name}"))
            importer.run
        end
    end
  
  
    private
    def _config
        GbifTaxonConfig.new
    end
end