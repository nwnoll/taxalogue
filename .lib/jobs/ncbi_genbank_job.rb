# frozen_string_literal: true

class NcbiGenbankJob
    attr_reader :taxon, :markers, :taxonomy, :result_file_manager, :use_http, :filter_params, :taxonomy_params, :region_params, :params, :download_only, :classify_only, :classify_dir

    FILE_DESCRIPTION_PART = 10
    RJUST_LEVEL_ONE = " " * 6
    RJUST_LEVEL_TWO = " " * 10

    DOWNLOAD_INFO_NAME = 'ncbi_genbank_download_info.txt'

    def initialize(result_file_manager:, use_http: false, params:)
        @params               = params
        @result_file_manager  = result_file_manager
        @use_http             = use_http
        @taxon                = params[:taxon_object]
        @markers              = params[:marker_objects]
        @root_download_dir    = nil
        @download_only        = params[:download][:genbank] || params[:download][:all]
        @classify_only        = params[:classify][:genbank] || params[:classify][:all]
        @classify_dir         = params[:classify][:classify_dir]
    end

    def run(release_info_struct)
        old_download_file_managers  = _get_download_file_managers_from_already_downloaded_dir(release_info_struct)
        new_download_file_managers  = old_download_file_managers.select { |dm| division_codes_for(division_ids).include?(dm.name) }

        if new_download_file_managers.empty?
            if classify_only
                MiscHelper.message_for_missing_download_file_managers("NCBI GenBank", taxon_name)

                return [result_file_manager, :cant_classify]
            elsif classify_dir
                ## TODO:
                ## here i shoul call functions for user provided dirs that have not been
                ## downloaded by taxalogue
            else
                new_download_file_managers  = _download_files 
            end
        end
        
        unless download_only
            erroneous_files_of = _classify_downloads(download_file_managers: new_download_file_managers)
            if erroneous_files_of.any?
                if classify_only || classify_dir
                    MiscHelper.message_for_malformed_downloads("NCBI GenBank", taxon_name)
    
                    return [result_file_manager, :cant_classify]
                else
                    new_download_file_managers  = _download_failed_files(new_download_file_managers, erroneous_files_of)
                    erroneous_files_of          = _classify_downloads(download_file_managers: new_download_file_managers)
                end
            end
        end

        download_file_managers = old_download_file_managers | new_download_file_managers

        _write_marshal_files(download_file_managers) unless classify_only || classify_dir

        used_download_file_managers  = download_file_managers.select { |dm| division_codes_for(division_ids).include?(dm.name) }
        
        return [result_file_manager, used_download_file_managers]
    end

    private
    def _get_download_file_managers_from_already_downloaded_dir(release_info_struct)
        return [] unless _has_already_downloaded_dir?(release_info_struct)
        
        begin
            # replace with download check helper func
            download_file_managers = _get_download_file_managers_from_marshal_dump(release_info_struct)
            download_file_managers = _update_download_file_managers_with_missing_divisions(download_file_managers, release_info_struct) unless release_info_struct.has_all_divisions
            

            unless download_only
                # replace with download check helper func
                _create_download_info_for_result_dir(release_info_struct, download_file_managers)
                DownloadCheckHelper.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir:release_info_struct.base_dir, result_file_manager: result_file_manager, source: self.class)
            end

            return download_file_managers
        rescue StandardError => e
            puts "Directory could not be used, starting download"
            pp e
            sleep 2

            return [] 
        end
    end

    def _has_already_downloaded_dir?(release_info_struct)
        !release_info_struct.base_dir.nil? if release_info_struct
    end

    def _get_download_file_managers_from_marshal_dump(release_info_struct)
        fm_from_md_name         = release_info_struct.base_dir + '.download_file_managers.dump'
        fm_from_md              = Marshal.load(File.open(fm_from_md_name, 'rb').read)
        download_file_managers  = fm_from_md

        return download_file_managers
    end

    def _update_download_file_managers_with_missing_divisions(download_file_managers, release_info_struct)
        download_file_managers_for_missing_divisions = []
        download_file_managers_for_missing_divisions = _download_files(missing_divisions: release_info_struct.missing_divisions)
        download_file_managers_for_missing_divisions.each { |fm| download_file_managers.push(fm) }

        return download_file_managers
    end

    def _download_files(missing_divisions: nil)
        ## TODO:
        ## maybe switch NcbiApi if taxon is of rank family?
        ## higher taxa might give an incomplete download
        ## it might be annoying if there will be searches
        ## for quite small taxa and the prog tries to download
        ## several gigabyte of data
        download_file_managers = []
        @root_download_dir = _get_release_dir

        _configs(missing_divisions).each do |config|
            download_file_manager = config.file_manager
            download_file_manager.create_dir
            
            downloader          = config.downloader.new(config: config)
            download_did_fail   = false

            begin
                downloader.run
            rescue StandardError => e
                download_did_fail = true
            end

            files = download_file_manager.files_of(dir: download_file_manager.dir_path)
            files.each do |file|
                if File.empty?(file)
                    download_did_fail = true
                    
                    break
                end
            end
            download_file_manager.status = download_did_fail ? 'failure' : 'success'
            
            download_file_managers.push(download_file_manager)
        end

        success = download_file_managers.all? { |fm| fm.status == 'success'}
        dl_path_public = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        
        if missing_divisions
            if download_only
                _update_download_info(paths: [dl_path_public, dl_path_hidden], success: success, download_file_managers: download_file_managers)
            else
                _update_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers)
            end
        else
            if download_only
                _write_download_info(paths: [dl_path_public, dl_path_hidden], success: success, download_file_managers: download_file_managers)
            else
                _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers)
            end
        end
        
        return download_file_managers
    end

    def _get_release_dir
        release_number = NcbiDownloadCheckHelper.get_current_genbank_release_number
        name = "release#{release_number}"
        
        return Pathname.new(name)
    end

    def _configs(missing_divisions = nil)
        configs = []
        release_dir = _get_release_dir

        if missing_divisions
            missing_divisions.each do |missing_division|
                configs.push(NcbiGenbankConfig.new(name: missing_division, markers: markers, use_http: use_http, parent_dir: release_dir))
            end
        else
            _groups.each do |name|
                configs.push(NcbiGenbankConfig.new(name: name, markers: markers, use_http: use_http, parent_dir: release_dir))
            end
        end

        return configs
    end

    def _groups
        return division_codes_for(animal_divisions) if taxon.canonical_name  == 'Animalia' || taxon.canonical_name  == 'Metazoa'
        
        return division_codes_for(division_ids)
    end

    def division_codes_for(ids)
        codes = []
        ids.each do |id|
            codes.push(NcbiDivision.code_for[id])
        end

        return codes
    end

    def animal_divisions
        [1, 2, 5, 6, 10]
    end

    def division_ids
        ids = NcbiDivision.get_division_id_by_taxon_name(taxon.canonical_name)
        
        return ids if ids
        
        ## should make multiple searches to find taxon in NCBI Genbank database
        abort "Could not find #{taxon.canonical_name} in NCBI Genbank please use a different taxon" if ids.nil?
    end

    def _update_download_info(paths:, success:, download_file_managers:)
        paths.each do |path|
            if path.descend.first.to_s == 'results'
                file = File.open(path, 'w')
                download_file_managers.each_with_index do |download_file_manager, i|
                    file.puts 'data:' if i == 0
                    file.puts "#{RJUST_LEVEL_ONE}#{download_file_manager.base_dir.to_s}; success: #{success}" if i == 0
                        
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{RJUST_LEVEL_TWO}#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}"
                end
            else
                file = File.open(path, 'r').read
                new_line_regex = /\r\n?|\n/
                base_dir_match = /data\:#{new_line_regex}(.*?)#{new_line_regex}/.match(file)
                base_dir_line = base_dir_match[1]
                base_dir_line_modified = base_dir_line
                base_dir_line_modified.gsub!('success: true', "success: #{success}")
                file.gsub!(base_dir_line, base_dir_line_modified)

                last_sub_dir_match = /#{new_line_regex}(.*?)#{new_line_regex}results\:/.match(file)
                last_sub_dir_line = last_sub_dir_match[1]
                last_sub_dir_line_modified = last_sub_dir_line
                download_file_managers.each do |download_file_manager|
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    last_sub_dir_line_modified += "\n#{RJUST_LEVEL_TWO}#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}"
                end
                file.gsub!(last_sub_dir_line, last_sub_dir_line_modified)
                file += "#{RJUST_LEVEL_ONE}#{result_file_manager.dir_path.to_s}" unless download_only

                out_file = File.open(path, 'w')
                out_file.puts file
            end
        end
    end

    def _write_download_info(paths:, success:, download_file_managers:)
        paths.each do |path|
            file = File.open(path, 'w')

            download_file_managers.each_with_index do |download_file_manager, i|
                if path.descend.first.to_s == 'results'
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".dup.prepend(RJUST_LEVEL_ONE) if i == 0
                    
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".dup.prepend(RJUST_LEVEL_TWO)
                else
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".dup.prepend(RJUST_LEVEL_ONE) if i == 0
                    
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".dup.prepend(RJUST_LEVEL_TWO)

                    file.puts 'results:' if i == (download_file_managers.size - 1)
                    file.puts "#{result_file_manager.dir_path.to_s}".dup.prepend(RJUST_LEVEL_ONE) if i == (download_file_managers.size - 1)
                end
            end
            file.rewind
        end
    end

    def _create_download_info_for_result_dir(release_info_struct, download_file_managers)
        result_dl_info_public_name = result_file_manager.dir_path + 'ncbi_genbank_download_info.txt'
        result_dl_info_hidden_name = result_file_manager.dir_path + '.ncbi_genbank_download_info.txt'

        success = download_file_managers.all? { |fm| fm.status == 'success'}

        paths = [result_dl_info_public_name, result_dl_info_hidden_name]
        paths.each do |path|
            file = File.open(path, 'w')
            download_file_managers.each_with_index do |download_file_manager, i|
                file.puts 'data:' if i == 0
                file.puts "#{release_info_struct.base_dir.to_s}; success: #{success}".dup.prepend(RJUST_LEVEL_ONE) if i == 0

                sub_directory_success = download_file_manager.status == 'success' ?  true : false
                file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".dup.prepend(RJUST_LEVEL_TWO)
            end
        end
    end

    def _update_already_downloaded_dir_on_new_result_dir(release_info_struct)
        pub_name = release_info_struct.base_dir + DOWNLOAD_INFO_NAME
        hid_name = release_info_struct.base_dir + ".#{DOWNLOAD_INFO_NAME}"

        paths = [pub_name, hid_name]
        paths.each do |path|
            next unless File.file?(path)

            file = File.open(path, 'a')
            file.puts "#{result_file_manager.dir_path.to_s}".dup.prepend(RJUST_LEVEL_ONE)
        end
    end

    def _classify_downloads(download_file_managers:)
        byebug
        erroneous_files_of = Hash.new
        download_file_managers.each do |download_file_manager|
            division_codes_for_taxon = division_codes_for(division_ids)
            next unless division_codes_for_taxon.include?(download_file_manager.name)
            next unless download_file_manager.status == 'success'
            files = download_file_manager.files_with_name_of(dir: download_file_manager.dir_path)
            
            files.each do |file|
                next unless File.file?(file)

                classifier = NcbiGenbankClassifier.new(file_name: file, file_manager: result_file_manager, params: params)
                erroneous_files = classifier.run ## result_file_manager creates new files and will push those into internal array
                erroneous_files_of[download_file_manager] = erroneous_files if erroneous_files.any?
            end
        end

        return erroneous_files_of
    end

    def _download_failed_files(download_file_managers, erroneous_files_of)
        @root_download_dir = _get_release_dir unless @root_download_dir

        erroneous_files_of.each do |download_file_manager, erroneous_files|
            
            download_file_managers.reject! { |fm| fm == download_file_manager }

            config = download_file_manager.config
            downloader = config.downloader.new(config: config)

            download_did_fail   = false

            begin
                base_names = []
                erroneous_files.each { |file| base_names.push(file.basename.to_s) }
                downloader.run(files_to_download: base_names)
            rescue SocketError => err
                download_did_fail = true
            rescue StandardError => err
                download_did_fail = true
            end

            files = download_file_manager.files_of(dir: download_file_manager.dir_path)
            files.each do |file|
                if File.empty?(file)
                    download_did_fail = true

                    break
                end
            end
            download_file_manager.status = download_did_fail ? 'failure' : 'success'
            
            download_file_managers.push(download_file_manager)
        end

        success = download_file_managers.all? { |fm| fm.status == 'success'}
        dl_path_public = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        
        _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers)
 
        return download_file_managers
    end

    def _write_marshal_files(download_file_managers)
        @root_download_dir = download_file_managers.first.base_dir.basename if download_file_managers.any? && @root_download_dir.nil?
        
        return :no_root_download_dir unless @root_download_dir
        
        MiscHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
        MiscHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump') 
    end

    ## UNUSED ATM
    def _write_result_files(fmanagers:)
        fmanagers.each do |root_dir|
            merged_download_file_name  = root_dir.dir_path + "merged.gz"
            download_info_file    = File.open(root_dir.dir_path + "download_info.tsv", 'w') 
            download_successes    = fmanagers.select { |m| m.status == 'success' }

            OutputFormat::MergedGenbankDownload.write_to_file(file_name: merged_download_file_name, data: download_successes, header_length: FILE_DESCRIPTION_PART, include_header: false)
            OutputFormat::DownloadInfo.write_to_file(file: download_info_file, fmanagers: fmanagers)
        end
    end
    
    ## UNUSED ATM
    def _merge_results
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
    end
end
