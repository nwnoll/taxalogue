# frozen_string_literal: true

class GbolJob
    attr_reader   :taxon, :markers, :taxonomy_params, :taxon_name , :result_file_manager, :filter_params

    def initialize(taxon:, markers: nil, taxonomy_params:, result_file_manager:, filter_params: nil)
      @taxon                = taxon
      @taxon_name           = taxon.canonical_name
      @markers              = markers
      @taxonomy_params      = taxonomy_params
      @result_file_manager  = result_file_manager
      @filter_params        = filter_params
    end

    def run
        download_file_managers = download_files

        _classify_downloads(download_file_managers: download_file_managers)
        
        return result_file_manager

    end

    def download_files
        fmanagers = []

        file_manager = _config.file_manager
        file_manager.create_dir

        ## TODO: uncomment just to test
        # _config.downloader.new(config: _config).run

        fmanagers.push(file_manager)
        
        return fmanagers
    end
  
  
    private
    def _classify_downloads(download_file_managers:)
        download_file_managers.each do |download_file_manager|
            next unless File.file?(download_file_manager.file_path)
    
            gbol_classifier   = GbolImporter.new(fast_run: true, file_name: download_file_manager.file_path, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, taxonomy_params: taxonomy_params)
            gbol_classifier.run ## result_file_manager creates new files and will push those into internal array
        end
    end

    def _config
        GbolConfig.new
    end
end
  