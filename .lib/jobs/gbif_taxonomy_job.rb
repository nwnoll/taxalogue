# frozen_string_literal: true

class GbifTaxonomyJob
    attr_reader :config

    DATE_TIME_FORMAT = "%Y%m%dT%H%M"

    def initialize
        @config = _config
    end
  
    def run
        file_manager = config.file_manager
        file_manager.create_dir

        downloader = config.downloader.new(config: config)
        # downloader.extend(MiscHelper.constantize("Printing::#{downloader.class}"))
        downloader.run

        _create_version_file

        config.importers.each do |importer_name, import_file|
            importer_class  = MiscHelper.constantize(importer_name)
            importer        = importer_class.new(file_manager: config.file_manager, file_name: import_file)
            # importer.extend(MiscHelper.constantize("Printing::#{importer_name}"))
            importer.run
        end
    end
  
  
    private
    def _config
        GbifTaxonomyConfig.new
    end

    def _create_version_file
        current_datetime        = DateTime.now
        current_datetime        = current_datetime.strftime(DATE_TIME_FORMAT)

        file_path = Pathname.new(config.file_manager.dir_path)
        file_path = file_path + "GBIF_TAXONOMY.txt"
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

