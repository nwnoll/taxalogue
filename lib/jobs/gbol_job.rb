# frozen_string_literal: true

class GbolJob
    attr_reader   :taxon, :markers, :taxonomy_params, :taxon_name , :result_file_manager, :filter_params, :region_params

    DOWNLOAD_INFO_NAME = 'gbol_download_info.txt'

    def initialize(taxon:, markers: nil, taxonomy_params:, result_file_manager:, filter_params: nil, region_params: nil)
      @taxon                = taxon
      @taxon_name           = taxon.canonical_name
      @markers              = markers
      @taxonomy_params      = taxonomy_params
      @result_file_manager  = result_file_manager
      @filter_params        = filter_params
      @region_params        = region_params
    end

    def run
        already_downloaded_dir = Helper.ask_user_about_gbol_download_dirs
        
        if already_downloaded_dir
          begin
            fm_from_md_name         = already_downloaded_dir + '.download_file_managers.dump'
            fm_from_md              = Marshal.load(File.open(fm_from_md_name, 'rb').read)
            download_file_manager  = fm_from_md
    
            Helper.create_download_info_for_result_dir(already_downloaded_dir: already_downloaded_dir, result_file_manager: result_file_manager, source: self)
          rescue StandardError => e
            puts "Release directory could not be used, starting download"
            sleep 2
    
            download_file_manager = download_files
    
            Helper.write_marshal_file(dir: download_file_manager.dir_path, data: download_file_manager, file_name: '.download_file_managers.dump')
            Helper.write_marshal_file(dir: download_file_manager.dir_path, data: taxon, file_name: '.taxon_object.dump')
          end
        else
    

        end

        begin 
            _classify_downloads(download_file_manager)
        rescue Zip::Error => e
            p e.inspect
            download_file_manager = download_files
          
            Helper.write_marshal_file(dir: download_file_manager.dir_path, data: download_file_manager, file_name: '.download_file_managers.dump')
            Helper.write_marshal_file(dir: download_file_manager.dir_path, data: taxon, file_name: '.taxon_object.dump')
        end
        
        return result_file_manager

    end

    def download_files
        file_manager = _config.file_manager
        file_manager.create_dir

        success = false
        begin
            _config.downloader.new(config: _config).run
            success = true
        rescue StandardError
            puts "GBOL Download crashed please try again"
        end

        dl_path_public = Pathname.new(file_manager.dir_path + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_manager: file_manager)
        
        return file_manager
    end


    private
    def _write_download_info(paths:, success:, download_file_manager:)

        paths.each do |path|
            file = File.open(path, 'w')
    
            basename = path.basename.to_s
    
            if path.descend.first.to_s == 'results'
                file.puts "corresponding data directory: #{download_file_manager.dir_path.to_s}"
            else
                file.puts "corresponding result directory: #{result_file_manager.dir_path.to_s}"
            end
    
            file.puts
            file.puts "success: #{success}"
            file.rewind
        end
    end


    def _classify_downloads(download_file_manager)
        return nil unless File.file?(download_file_manager.file_path)

        gbol_classifier   = GbolImporter.new(fast_run: true, file_name: download_file_manager.file_path, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, taxonomy_params: taxonomy_params, region_params: region_params)
        gbol_classifier.run ## result_file_manager creates new files and will push those into internal array
    end

    def _config
        GbolConfig.new
    end
end
  