# frozen_string_literal: true

class NcbiGenbankJob
    attr_reader :taxon, :markers, :taxonomy, :result_file_manager, :use_http, :filter_params, :taxonomy_params, :region_params, :params, :download_only, :classify_only, :classify_dir


    FILE_DESCRIPTION_PART       = 10
    RJUST_LEVEL_ONE             = " " * 6
    RJUST_LEVEL_TWO             = " " * 10


    DOWNLOAD_INFO_NAME          = 'ncbi_genbank_download_info.txt'
    PER_FILE_DOWNLOAD_INFO_NAME = 'ncbi_genbank_per_file_download_info.txt'


    def initialize(result_file_manager:, use_http: false, params:)
        @params               = params
        @result_file_manager  = result_file_manager
        @use_http             = use_http
        @taxon                = params[:taxon_object]
        @markers              = params[:marker_objects]
        @root_download_dir    = nil
        @download_only        = params[:download][:genbank] || params[:download][:genbank_dir] || params[:download][:all]
        @classify_only        = params[:classify][:genbank] || params[:classify][:all]
        @classify_dir         = params[:classify][:classify_dir]
    end


    def run(release_info_struct)
        ## Here I make surethat the provided GenBank dir is the current one
        ## Since NCBI only provides the current genbank release, an old provided genbank dir
        ## would be not added to if we have missing divisions, instead the current release
        ## would be downloaded. This results in a hybrid and should be avoided
        if params[:download][:genbank_dir]
            current_release_dir = _get_release_dir
            return [result_file_manager, :cant_download]        if current_release_dir.nil?
            return [result_file_manager, :not_current_release]  unless params[:download][:genbank_dir].basename == current_release_dir
        end


        old_download_file_managers  = _get_download_file_managers_from_already_downloaded_dir(release_info_struct)
        new_download_file_managers  = old_download_file_managers.select { |dm| division_codes_for(division_ids).include?(dm.name) }


        # TODO: 
        # - test genbank_dir
        #   - main problem is currently non integtration of missing divisions
        #   - need to change files_per_division retrieval in general
        #   - files_per_division has to be written if missing division, BUT without overwriting
        # - think about descend
        # - think and add to if new_download_file_managers.empty?
        # - go through todo on paper


        if new_download_file_managers.empty?
            if classify_only
                MiscHelper.message_for_missing_download_file_managers("NCBI GenBank", taxon.canonical_name)


                return [result_file_manager, :cant_classify]
            elsif classify_dir
                ## TODO:
                ## here i shoul call functions for user provided dirs that have not been
                ## downloaded by taxalogue
            else
                new_download_file_managers = _download_files
                if new_download_file_managers == :cant_download
                    return [result_file_manager, :cant_download]
                end
            end
        else # got new_download_file_managers!
            if download_only
                if params[:download][:genbank_dir]
                    new_download_file_managers  = _download_failed_files2(new_download_file_managers)
                    if new_download_file_managers == :cant_download
                        return [result_file_manager, :cant_download]
                    end
                end
            end
        end


        unless download_only
            erroneous_files_of = _classify_downloads(download_file_managers: new_download_file_managers)
            if erroneous_files_of == :cant_classify
                return [result_file_manager, :cant_classify]
            end

            
            if erroneous_files_of.any?
                if classify_only || classify_dir
                    MiscHelper.message_for_malformed_downloads("NCBI GenBank", taxon.canonical_name)
    

                    return [result_file_manager, :cant_classify]
                else
                    new_download_file_managers  = _download_failed_files(new_download_file_managers, erroneous_files_of)
                    if new_download_file_managers == :cant_download
                        return [result_file_manager, :cant_download]
                    end


                    erroneous_files_of = _classify_downloads(download_file_managers: new_download_file_managers)
                    if erroneous_files_of == :cant_classify
                        return [result_file_manager, :cant_classify]
                    end
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
            download_file_managers = _get_download_file_managers_from_marshal_dump(release_info_struct)
            
            
            unless release_info_struct.has_all_divisions
                download_file_managers = _update_download_file_managers_with_missing_divisions(download_file_managers, release_info_struct)
            end
            return [] if download_file_managers.empty?


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
        return [] if download_file_managers_for_missing_divisions == :cant_download
        
        
        download_file_managers_for_missing_divisions.each { |fm| download_file_managers.push(fm) }
        return download_file_managers
    end


    def _download_files(missing_divisions: nil)
        ## TODO:
        ## NEXT!!
        ## Big problem is atm
        ## if I have missing divisions, then
        ## 1. it does not write files_per_division
        ##      - it should also not overwrite existing files_per_division
        ## 2. it seems to downlad mam in rod or others
        ##      - this is most likely due to no change in files_per_division?
        download_file_managers  = []
        @root_download_dir      = _get_release_dir
        return :cant_download if @root_download_dir.nil?


        files_per_division  = nil
        configs             = _configs(missing_divisions)
        

        ## Get all GenBank filenames of requested taxon
        begin
            files_per_division = FtpDownloader.get_files_per_division(configs)
            unless files_per_division
                sleep 10
                
                
                files_per_division  = FtpDownloader.get_files_per_division(configs)
            end
        rescue StandardError => e
            ## Just for the possibility of no Internet connection or FTP restrictions of users
            ## will be handled with if files_per_division
        end


        ## since we dont have any connection to FTP, we can set failure to every download_file_manager
        if files_per_division.nil?
            configs.each do |config|
                download_file_manager = config.file_manager
                download_file_manager.status = 'failure'
                download_file_managers.push(download_file_manager)
            end


            ## Since we already failed, theres no need to go through all configs anymore
            configs = []
        end


        configs.each do |config|
            download_file_manager = config.file_manager
            download_file_manager.create_dir


            downloader              = config.downloader.new(config: config)
            download_did_fail       = false
            not_downloaded_files    = []


            begin

                ## if I already downloaded for another dfm, I will recreate it
                ## and after that I will download all again
                ## I should anyways only have the files for the current dfm
                ## have to change it like in _download_failed_files
                files_per_division = FtpDownloader.get_files_per_division(configs)
                if files_per_division
                    downloader.run(download_success_of_division_file: files_per_division)
                else
                    sleep 10
                    
                    
                    files_per_division  = FtpDownloader.get_files_per_division(configs)
                    downloader.run(download_success_of_division_file: files_per_division) if files_per_division
                end


                download_did_fail = files_per_division.nil?
            rescue StandardError => e
                download_did_fail = true
            end


            files_per_division.each do |file_name, download_success|
                unless download_success
                    if file_name.match?(config.name)
                        download_did_fail = true
                        break
                    end
                end
            end
            download_file_manager.status = download_did_fail ? 'failure' : 'success'


            ## TODO:
            ## need to test the whole _download_failed_files
            ## and download_files
            ## i could also use it dor download->genbank_dir


            download_file_managers.push(download_file_manager)
        end


        success = download_file_managers.all? { |fm| fm.status == 'success'}
        dl_path_public      = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden      = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public      = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden      = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")


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


            _write_per_file_dl_info(files_per_division)
        end


        return download_file_managers
    end


    def _write_per_file_dl_info(files_per_division)
        return nil unless files_per_division


        pf_dl_path_public   = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + PER_FILE_DOWNLOAD_INFO_NAME)
        pf_dl_path_hidden   = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{PER_FILE_DOWNLOAD_INFO_NAME}")
        file_pf_public      = File.open(pf_dl_path_public, 'w')


        PP.pp(files_per_division, file_pf_public)
        MiscHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, file_name: pf_dl_path_hidden.basename.sub_ext('.dump'), data: files_per_division)
    end


    def _get_release_dir
        release_number = NcbiDownloadCheckHelper.get_current_genbank_release_number
        if release_number.nil?
            sleep 5
            release_number = NcbiDownloadCheckHelper.get_current_genbank_release_number
            

            return nil if release_number.nil?
        end
        name = "release#{release_number}"


        return Pathname.new(name)
    end


    def _configs(missing_divisions = nil)
        configs = []


        if missing_divisions
            missing_divisions.each do |missing_division|
                configs.push(NcbiGenbankConfig.new(name: missing_division, markers: markers, use_http: use_http, parent_dir: @root_download_dir))
            end
        else
            _groups.each do |name|
                configs.push(NcbiGenbankConfig.new(name: name, markers: markers, use_http: use_http, parent_dir: @root_download_dir))
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
        abort "Could not find #{taxon.canonical_name} in NCBI GenBank please use a different taxon" if ids.nil?
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


    def _get_markers_of_releases(genbank_marker_info_of)
       
        markers_of_releases = Hash.new
        genbank_marker_info_of.keys.each do |k|
         
            k =~ /\/(release\d+)\//
            release_str = $1
            next unless release_str
            
            if markers_of_releases.key?(release_str)
              
                genbank_marker_info_of[k].keys.each do |marker_str|
                    markers_of_releases[release_str] = genbank_marker_info_of[k].push(marker_str) unless markers_of_releases[release_str].include?(marker_str)
                end
            else
                markers_of_releases[release_str] = genbank_marker_info_of[k].keys
            end
        end
       

        return markers_of_releases
    end

    def _get_markers_of_downloaded_release(download_file_manager:, markers_of_releases:, genbank_marker_info_of:)
        return Hash.new if markers_of_releases.empty?
        
        markers_of_downloaded_release = Hash.new
        download_file_manager.config.markers.each do |marker|
            
            release_str = download_file_manager.config.parent_dir.to_s
            if markers_of_releases.key?(release_str)
                
                if markers_of_releases[release_str].include?(marker)
                    markers_of_downloaded_release[release_str].push(marker.marker_tag.to_s) unless markers_of_downloaded_release[release_str].include?(marker)
                else
                    markers_of_downloaded_release[release_str] = [marker.marker_tag.to_s]
                end
            end
        end
    
        return markers_of_downloaded_release  
    end

    def _classify_downloads(download_file_managers:)
        
        MiscHelper.OUT_header('Starting to classify NCBI GenBank downloads')


        erroneous_files_of = Hash.new { |h,k| h[k] = [] }
        download_file_managers.each do |download_file_manager|
            division_codes_for_taxon = division_codes_for(division_ids)
            next unless division_codes_for_taxon.include?(download_file_manager.name)
            next unless download_file_manager.status == 'success'
            

            genbank_marker_info_of = MiscHelper.get_genbank_marker_info
            if genbank_marker_info_of
                
                markers_of_releases           = _get_markers_of_releases(genbank_marker_info_of)
                markers_of_downloaded_release = _get_markers_of_downloaded_release(download_file_manager: download_file_manager, markers_of_releases: markers_of_releases, genbank_marker_info_of: genbank_marker_info_of)
                ## if the hash is empty than the release from the download_file_manager was not found
                #  therefore we have to search for the markers in that release
                if markers_of_downloaded_release.empty?
                    MiscHelper.search_for_markers_in_genbank_files(marker_objects: @markers, dir_name: download_file_manager.dir_path)
                    sleep 0.1
                end

                
                ## get info for missing markers
                markers_of_downloaded_release.keys.each do |release|
                    
                    ## should actually not happen but to be sure
                    next unless markers_of_releases.key?(release)
                    
                    markers_to_download = []
                    markers_of_downloaded_release[release].each do |marker_str|
                        markers_to_download.push(marker_str) unless markers_of_releases[release].include?(marker_str)
                    end
                    next unless markers_to_download.any? # skip if all markers are present for release


                    marker_objects = []
                    markers_to_download.each do |marker_str|
                        marker_objects.push(Marker.new(query_marker_name: marker_str))
                    end
                    
                    MiscHelper.search_for_markers_in_genbank_files(marker_objects: marker_objects, dir_name: download_file_manager.dir_path)
                    sleep 0.1
                end

                
                MiscHelper.create_genbank_marker_info_file
                sleep 0.1
            else # no file in .config 

                MiscHelper.search_for_markers_in_genbank_files(marker_objects: @markers, dir_name: download_file_manager.dir_path)
                sleep 0.1
                MiscHelper.create_genbank_marker_info_file
                sleep 0.1
                
                
                genbank_marker_info_of = MiscHelper.get_genbank_marker_info
                return :cant_classify unless genbank_marker_info_of
            end


            files = download_file_manager.files_with_name_of(dir: download_file_manager.dir_path)
            #files = files.sample(30)# for quicker tests
           

            begin
                erroneous_files_of = _parallel_classification(files: files, genbank_marker_info_of: genbank_marker_info_of, erroneous_files_of: erroneous_files_of, download_file_manager: download_file_manager)
            rescue Errno::EMFILE 

                sleep 10
                begin
                    erroneous_files_of = _parallel_classification(files: files, genbank_marker_info_of: genbank_marker_info_of, erroneous_files_of: erroneous_files_of, download_file_manager: download_file_manager)
                rescue Errno::EMFILE
                    puts "Errno::EMFILE => Too many open files, please consider to increase the limit of open files."
                    exit
                end
            end
        end


        return erroneous_files_of
    end

    def _parallel_classification(files:, genbank_marker_info_of:, erroneous_files_of:, download_file_manager:)
        
        ## since the dereplication uses the sqlite database, we cant  parallelize it
        num_processes = DerepHelper.do_derep ? 1 : params[:num_cores] 
        Parallel.map(files, in_processes: num_processes) do |file|
            next unless File.file?(file)
            next unless genbank_marker_info_of[file.to_s]

            
            ## search for marker in file
            found_marker = false
            @markers.each do |marker|
                if genbank_marker_info_of[file.to_s][marker.marker_tag.to_s]
                    found_marker =  true
                    break 
                end
            end
            next unless found_marker
            
            
            classifier = NcbiGenbankClassifier.new(file_name: file, file_manager: result_file_manager, params: params)
            erroneous_files = classifier.run ## result_file_manager creates new files and will push those into internal array
            erroneous_files_of[download_file_manager].push(erroneous_files).flatten! if erroneous_files.any?
        end
       

        return erroneous_files_of
    end


    def _download_failed_files2(download_file_managers, erroneous_files_of = Hash.new)
        @root_download_dir = _get_release_dir unless @root_download_dir
        return :cant_download if @root_download_dir.nil?


        configs                     = []
        files_per_division          = nil
        download_file_managers.each { |dfm| configs.push(dfm) }


        ## Get files_per_division
        begin
            pf_dl_dump = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{PER_FILE_DOWNLOAD_INFO_NAME}").sub_ext('.dump')
            files_per_division = DownloadCheckHelper.get_object_from_marshal_file(pf_dl_dump)
        rescue StandardError
            begin
                files_per_division = FtpDownloader.get_files_per_division(configs)
                unless files_per_division
                    sleep 10
                    
                    
                    files_per_division  = FtpDownloader.get_files_per_division(configs)
                end
                files_per_division.keys.each { |k| files_per_division[k] = true } if files_per_division
            rescue StandardError
                ## Just for the possibility of no Internet connection or FTP restrictions of users
                ## will be handled with if files_per_division
            end
        end


        ## NOT TESTED!
        if files_per_division
            download_file_managers_with_failures = erroneous_files_of.keys
            files_per_division.each do |file_name, download_success|
                next if download_success


                download_file_managers.each do |dfm|
                    if file_name.match?(dfm.name) && !download_file_managers_with_failures.include?(dfm)
                        download_file_managers_with_failures.push(dfm)
                    end
                end
            end


            download_file_managers_with_failures.each do |download_file_manager|
                download_did_fail           = false
                files_per_current_division  = Hash.new
                config                      = download_file_manager.config
                downloader                  = config.downloader.new(config: config)
                
                
                files_per_division.keys.select do |k| 
                    if k.match?(download_file_manager.name)
                        files_per_current_division[k] = files_per_division[k]
                    end
                end


                if erroneous_files_of[download_file_manager]
                    erroneous_files_of[download_file_manager].each do |file|
                        files_per_current_division[file.basename.to_s] = false
                    end
                end


                begin
                    downloader.run(download_success_of_division_file: files_per_current_division)
                rescue StandardError => err
                    download_did_fail = true
                end


                unless download_did_fail
                    files_per_current_division.each do |file_name, download_success|
                        unless download_success
                            if file_name.match?(config.name)
                                download_did_fail = true
                                break
                            end
                        end
                    end
                end
                download_file_manager.status = download_did_fail ? 'failure' : 'success'


                download_file_managers.reject! { |fm| fm == download_file_manager }
                download_file_managers.push(download_file_manager)


                ## merge current with overall
                files_per_current_division.each do |current_file_name, current_download_success|
                    files_per_division[current_file_name] = current_download_success
                end
            end
        else # files_per_division == nil
            erroneous_files_of.each do |download_file_manager, erroneous_files|
                if erroneous_files.any?
                    download_file_manager.status = 'failure'
                else
                    download_file_manager.status = 'success'
                end


                download_file_managers.reject! { |fm| fm == download_file_manager }
                download_file_managers.push(download_file_manager)
            end
        end


        success = download_file_managers.all? { |fm| fm.status == 'success'}
        dl_path_public = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        

        if download_only
            _write_download_info(paths: [dl_path_public, dl_path_hidden], success: success, download_file_managers: download_file_managers)
        else
            _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers)
        end
        _write_per_file_dl_info(files_per_division)


        return download_file_managers
    end


    def _download_failed_files(download_file_managers, erroneous_files_of)
        @root_download_dir = _get_release_dir unless @root_download_dir
        return :cant_download if @root_download_dir.nil?


        configs                     = []
        files_per_division          = nil
        download_file_managers.each { |dfm| configs.push(dfm) }


        ## Get files_per_division
        begin
            pf_dl_dump = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{PER_FILE_DOWNLOAD_INFO_NAME}").sub_ext('.dump')
            files_per_division = DownloadCheckHelper.get_object_from_marshal_file(pf_dl_dump)
        rescue StandardError
            begin
                files_per_division = FtpDownloader.get_files_per_division(configs)
                unless files_per_division
                    sleep 10
                    
                    
                    files_per_division  = FtpDownloader.get_files_per_division(configs)
                end
                files_per_division.keys.each { |k| files_per_division[k] = true } if files_per_division
            rescue StandardError
                ## Just for the possibility of no Internet connection or FTP restrictions of users
                ## will be handled with if files_per_division
            end
        end


        ## NOT TESTED!
        if files_per_division
            erroneous_files_of.each do |download_file_manager, erroneous_files|
                download_did_fail = false
                download_file_managers.reject! { |fm| fm == download_file_manager }


                ## each dfm get its own files_per_division,
                ## afterwards i will be merged again
                files_per_current_division = Hash.new
                files_per_division.keys.select do |k| 
                    if k.match?(download_file_manager.name)
                        files_per_current_division[k] = files_per_division[k]
                    end
                end


                erroneous_files.each { |file| files_per_current_division[file.basename.to_s] = false }
                config      = download_file_manager.config
                downloader  = config.downloader.new(config: config)
                

                begin
                    downloader.run(download_success_of_division_file: files_per_current_division)
                rescue StandardError => err
                    download_did_fail = true
                end


                unless download_did_fail
                    files_per_current_division.each do |file_name, download_success|
                        unless download_success
                            if file_name.match?(config.name)
                                download_did_fail = true
                                break
                            end
                        end
                    end
                end
                download_file_manager.status = download_did_fail ? 'failure' : 'success'


                download_file_managers.push(download_file_manager)
                ##
                ##


                erroneous_files.each { |file| files_per_division[file.basename.to_s] = false }
                config      = download_file_manager.config
                downloader  = config.downloader.new(config: config)


                ## Problem here seems to be that:
                ## If I have multiple divisions, wich are reflected as multiple dfms
                ## then even if the first dfm was for inv it would try to download
                ## also rod, mam etc... if the download fails for those non-dfm files
                ## then the dfm for inv would be considered as a failure...
                ## I need to restrict the files_per_division per dfm
                begin
                    downloader.run(download_success_of_division_file: files_per_division)
                rescue StandardError => err
                    download_did_fail = true
                end


                unless download_did_fail
                    files_per_division.each do |file_name, download_success|
                        unless download_success
                            if file_name.match?(config.name)
                                download_did_fail = true
                                break
                            end
                        end
                    end
                end
                download_file_manager.status = download_did_fail ? 'failure' : 'success'


                download_file_managers.push(download_file_manager)
            end


            if erroneous_files_of.empty?
                download_did_fail = false
                download_file_managers.reject! { |fm| fm == download_file_manager }


                config      = download_file_manager.config
                downloader  = config.downloader.new(config: config)


                begin
                    downloader.run(download_success_of_division_file: files_per_division)
                rescue StandardError => err
                    download_did_fail = true
                end


                unless download_did_fail
                    files_per_division.each do |file_name, download_success|
                        unless download_success
                            if file_name.match?(config.name)
                                download_did_fail = true
                                break
                            end
                        end
                    end
                end
                download_file_manager.status = download_did_fail ? 'failure' : 'success'


                download_file_managers.push(download_file_manager)
            end
        end


        if !files_per_division
            erroneous_files_of.each do |download_file_manager, erroneous_files|
                if erroneous_files.any?
                    download_file_manager.status = 'failure'
                else
                    download_file_manager.status = 'success'
                end
            end
        end



        success = download_file_managers.all? { |fm| fm.status == 'success'}
        dl_path_public = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        
        
        _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers)
        _write_per_file_dl_info(files_per_division)


        return download_file_managers
    end


    def _write_marshal_files(download_file_managers)
        @root_download_dir = download_file_managers.first.base_dir.basename if download_file_managers.any? && @root_download_dir.nil?
        return :no_root_download_dir unless @root_download_dir
        

        MiscHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
        MiscHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump') 
    end
end
