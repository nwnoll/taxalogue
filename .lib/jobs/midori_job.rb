# frozen_string_literal: true

class MidoriJob
    attr_reader :taxon, :result_file_manager, :params, :download_only, :classify_only, :classify_dir, :taxon_name

    DOWNLOAD_INFO_NAME = 'midori_download_info.txt'

    def initialize(result_file_manager:, params:)
        @result_file_manager  = result_file_manager
        @params               = params
        @taxon                = params[:taxon_object]
        @taxon_name           = taxon.canonical_name
        @download_only        = params[:download][:midori] || params[:download][:all]
        @classify_only        = params[:classify][:midori] || params[:classify][:all]
        @classify_dir         = params[:classify][:midori_dir]
    end

    def run(already_downloaded_dir)
        download_file_manager = _get_download_file_manager_from_already_downloaded_dir(already_downloaded_dir)
        
        if download_file_manager.nil?
            if classify_only
                MiscHelper.message_for_missing_download_file_managers("MIDORI", taxon_name)

                return [result_file_manager, :cant_classify]
            elsif classify_dir
                ## TODO:
                ## here i shoul call functions for user provided dirs that have not been
                ## downloaded by taxalogue
            else
                download_file_manager   = _download_files 
            end
        end

        unless download_only
            error_file_name  = _classify_downloads(download_file_manager)
            if error_file_name
                if classify_only || classify_dir
                    MiscHelper.message_for_malformed_downloads("MIDORI", taxon_name)
    
                    return [result_file_manager, :cant_classify]
                else
                    download_file_managers  = _download_files
                    error_file_name         = _classify_downloads(download_file_manager)
                end
            end
        end

        _write_marshal_files(download_file_manager) unless classify_only || classify_dir

        return [result_file_manager, [download_file_manager]]
    end

    def _get_download_file_manager_from_already_downloaded_dir(already_downloaded_dir)
        return nil unless already_downloaded_dir
        
        begin
            download_file_manager = DownloadCheckHelper.get_object_from_marshal_file(already_downloaded_dir + '.download_file_managers.dump')
    
            unless download_only
                DownloadCheckHelper.create_download_info_for_result_dir(download_file_managers:[download_file_manager], result_file_manager: result_file_manager, source: self.class)
                DownloadCheckHelper.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir: already_downloaded_dir, result_file_manager: result_file_manager, source: self.class)
            end

            return download_file_manager
        rescue StandardError => e
            puts "Release directory could not be used."
            pp e
            sleep 2
            
            return nil
        end
    end

    def _download_files
        file_manager = _config.file_manager
        file_manager.create_dir

        success = false
        begin
            _config.downloader.new(config: _config).run
            if File.empty?(file_manager.file_path)
                file_manager.status = 'failure'
            else
                success = true
                file_manager.status = 'success'
            end
        rescue StandardError
            puts "MIDORI Download crashed please try again"
            success = false
        end

        dl_path_public = Pathname.new(file_manager.dir_path + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        
        if download_only
            DownloadCheckHelper.write_download_info(paths: [dl_path_public, dl_path_hidden], success: success, download_file_managers: [file_manager], result_file_manager: result_file_manager)
        else
            DownloadCheckHelper.write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: [file_manager], result_file_manager: result_file_manager)
        end

        return file_manager
    end


    private
    def _write_download_info(paths:, success:, download_file_manager:)

        paths.each do |path|
            file = File.open(path, 'w')
    
            basename = path.basename.to_s
    
            if path.descend.first.to_s == 'results'
                file.puts "data directory: #{download_file_manager.dir_path.to_s}"
            else
                file.puts "result directory: #{result_file_manager.dir_path.to_s}"
            end
    
            file.puts
            file.puts "success: #{success}"
            file.rewind
        end
    end

    def _write_marshal_files(download_file_manager)
        MiscHelper.write_marshal_file(dir: download_file_manager.dir_path, data: download_file_manager, file_name: '.download_file_managers.dump')
        MiscHelper.write_marshal_file(dir: download_file_manager.dir_path, data: taxon, file_name: '.taxon_object.dump')
    end


    def _classify_downloads(download_file_manager)
        return nil unless File.file?(download_file_manager.file_path)

        midori_classifier   = MidoriClassifier.new(params: params, file_name: download_file_manager.file_path, file_manager: result_file_manager)
        error_file = midori_classifier.run ## result_file_manager creates new files and will push those into internal array
    
        return error_file
    end

    def _config
        MidoriConfig.new
    end
end
  
