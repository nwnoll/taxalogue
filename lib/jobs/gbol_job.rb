# frozen_string_literal: true

class GbolJob
    attr_reader   :taxon, :markers, :taxonomy, :taxon_name , :result_file_manager, :file_path

    ## TODO: file_path should be preliminiary, hopefully the GBOL release will be available again
    def initialize(taxon:, markers: nil, taxonomy:, result_file_manager:, file_path:)
      @taxon                = taxon
      @taxon_name           = taxon.canonical_name
      @markers              = markers
      @taxonomy             = taxonomy
      @result_file_manager  = result_file_manager
      @file_path            = file_path
    end

    def run
        ## TODO change back when release is available again
        # _config.downloader.new(config: _config).run

        download_file_managers = download_files

        _classify_downloads(download_file_managers: download_file_managers)
        
        return result_file_manager

    end

    def download_files
        fmanagers = []

        file_manager = _config.file_manager
        file_manager.create_dir
        file_manager.status = 'success' # TODO: preliminary

        fmanagers.push(file_manager)
        
        return fmanagers
    end
  
  
    private
    def _classify_downloads(download_file_managers:)
        download_file_managers.each do |download_file_manager|
            next unless download_file_manager.status == 'success'
            ## TODO: next condition will fail since we ware unable to download at the moment. therefore i copied a version into that folder...
            ## needs to be changed...
            ## here I also have to change the config file at the moment it says it is zip but the whole processong in the
            ## GBol importer is base on a csv file... maybe botth? but at the moment I just change it to CSV in the config file
            next unless File.file?(file_path)
    
            # gbol_classifier   = GbolImporter.new(fast_run: true, file_name: download_file_manager.file_path, query_taxon_object: taxon, file_manager: result_file_manager)
            gbol_classifier   = GbolImporter.new(fast_run: true, file_name: file_path, query_taxon_object: taxon, file_manager: result_file_manager)
            gbol_classifier.run ## result_file_manager creates new files and will push those into internal array
        end
    end

    def _config
        GbolConfig.new
    end
end
  