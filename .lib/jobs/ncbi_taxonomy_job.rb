# frozen_string_literal: true

class NcbiTaxonomyJob
    attr_reader :config

    DATE_TIME_FORMAT = "%Y%m%dT%H%M"

    def initialize(config_file_name:)
        @config = _config(config_file_name)
    end

    def run
        file_manager = config.file_manager
        file_manager.create_dir

        downloader = config.downloader.new(config: config)
        downloader.run

        _create_version_file

        config.importers.each do |importer_name, import_file|
            importer_class  = MiscHelper.constantize(importer_name)
            importer        = importer_class.new(file_manager: file_manager, file_name: import_file)
            importer.run
        end
    end

    private
    def _config(config_file_name)
        params = MiscHelper.json_file_to_hash(config_file_name)
        config = Config.new(params)

        return config
    end

    def _create_version_file
        current_datetime        = DateTime.now
        current_datetime        = current_datetime.strftime(DATE_TIME_FORMAT)

        file_path = Pathname.new(config.file_manager.dir_path)
        file_path = file_path + "NCBI_TAXONOMY.txt"
        file = File.open(file_path, 'w')

        file.print 'name: '
        file.puts config.name

        file.print 'source: '
        file.puts config.address

        file.print 'used_files: '
        file.puts config.importers.values.join(', ')

        file.print 'timestamp: '
        file.puts current_datetime
        file.close
    end
end
