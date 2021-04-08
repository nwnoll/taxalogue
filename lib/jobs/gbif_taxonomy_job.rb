# frozen_string_literal: true

class GbifTaxonomyJob
    def initialize
    end
  
    def run
        file_manager = _config.file_manager
        file_manager.create_dir

        downloader = _config.downloader.new(config: _config)
        # downloader.extend(MiscHelper.constantize("Printing::#{downloader.class}"))
        downloader.run

        _config.importers.each do |importer_name, import_file|
            importer_class  = MiscHelper.constantize(importer_name)
            importer        = importer_class.new(file_manager: _config.file_manager, file_name: import_file)
            # importer.extend(MiscHelper.constantize("Printing::#{importer_name}"))
            importer.run
        end
    end
  
  
    private
    def _config
        GbifTaxonomyConfig.new
    end
end