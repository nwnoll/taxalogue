# frozen_string_literal: true

class NcbiTaxonomyJob
    attr_reader :config

    def initialize(config_file_name:)
        @config = _config(config_file_name)
    end

    def run
        file_manager = config.file_manager
        file_manager.create_dir

        downloader = config.downloader.new(config: config)
        # downloader.extend(Helper.constantize("Printing::#{downloader.class}"))
        downloader.run

        config.importers.each do |importer_name, import_file|
            importer_class  = Helper.constantize(importer_name)
            importer        = importer_class.new(file_manager: file_manager, file_name: import_file)
            importer.run
        end
    end

    private
    def _config(config_file_name)
        params = Helper.json_file_to_hash(config_file_name)
        config = Config.new(params)

        return config
    end
end