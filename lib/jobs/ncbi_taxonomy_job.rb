# frozen_string_literal: true

class NcbiTaxonomyJob
    def run
        file_structure = _config.file_structure
        file_structure.extend(Helper.constantize("Printing::#{file_structure.class}"))
        file_structure.create_directory

        downloader = _config.downloader.new(config: _config)
        downloader.extend(Helper.constantize("Printing::#{downloader.class}"))
        downloader.run

        _config.importers.each do |importer_name, import_file|
            importer_class  = Helper.constantize(importer_name)
            importer        = importer_class.new(archive_name: _config.file_structure.file_path, file_name: import_file)
            importer.extend(Helper.constantize("Printing::#{importer_name}"))
            importer.run
        end
    end
  
  
    private
    def _config
        NcbiTaxonomyConfig.new
    end
end