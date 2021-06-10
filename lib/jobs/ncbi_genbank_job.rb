# frozen_string_literal: true

class NcbiGenbankJob
    attr_reader :taxon, :markers, :taxonomy, :result_file_manager, :use_http, :filter_params, :taxonomy_params, :region_params, :params

    FILE_DESCRIPTION_PART = 10
    RJUST_LEVEL_ONE = " " * 6
    RJUST_LEVEL_TWO = " " * 10

    DOWNLOAD_INFO_NAME = 'ncbi_genbank_download_info.txt'

    def initialize(taxon:, markers: nil, taxonomy:, result_file_manager:, use_http: false, filter_params: nil, taxonomy_params:, region_params: nil, params: nil)
        @taxon                = taxon
        @markers              = markers
        @taxonomy             = taxonomy
        @result_file_manager  = result_file_manager
        @use_http             = use_http
        @filter_params        = filter_params
        @taxonomy_params      = taxonomy_params
        @region_params        = region_params
        @params               = params
        @root_download_dir    = nil
    end

    def run
        release_info_struct     = _get_already_existing_download_dirs
        download_file_managers  = _get_download_file_managers_from_already_downloaded_dir(release_info_struct)
        download_file_managers  = _download_files if download_file_managers.empty?
        erroneous_files_of      = _classify_downloads(download_file_managers: download_file_managers)
        download_file_managers  = _download_failed_files(download_file_managers, erroneous_files_of) if erroneous_files_of.any?

        return result_file_manager
    end

    private
    
    def _get_already_existing_download_dirs
        NcbiDownloadCheckHelper.ask_user_about_download_dirs(params)
    end

    def _get_download_file_managers_from_already_downloaded_dir(release_info_struct)
        return [] unless _has_already_downloaded_dir?(release_info_struct)
        
        begin
            download_file_managers = _get_download_file_managers_from_marshal_dump(release_info_struct)
            download_file_managers = _update_download_file_managers_with_missing_divisions(download_file_managers, release_info_struct) unless release_info_struct.has_all_divisions
            
            _create_download_info_for_result_dir(release_info_struct, download_file_managers)
            _update_already_downloaded_dir_on_new_result_dir(release_info_struct)
    
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
        ## highert taxa might give an incomplete download
        ## it might be annoying if there will be searches
        ## for quite small taxa and the prog tries to download
        ## several gigabyte of data
        fmanagers = []
        @root_download_dir = _get_release_dir

        _configs(missing_divisions).each do |config|
            file_manager = config.file_manager
            file_manager.create_dir
            
            ## TODO: uncomment again, this is because there are some ports not open at the museum...
            ## This might be the case for other institutions too
            ## if ftp is usdownload_did_failed then I might catch that exception and try to download via http
            
            downloader          = config.downloader.new(config: config)
            download_did_fail   = false

            begin
                downloader.run
            rescue SocketError => e
                download_did_fail = true
            rescue StandardError => e
                download_did_fail = true
            end

            files = file_manager.files_of(dir: file_manager.dir_path)
            files.each do |file|
                if File.empty?(file)
                    download_did_fail = true
                    break
                end
            end
            file_manager.status = download_did_fail ? 'failure' : 'success'
            
            fmanagers.push(file_manager)
        end

        success = fmanagers.all? { |fm| fm.status == 'success'}
        dl_path_public = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        
        _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: fmanagers)
        DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
        DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump') 
        
        return fmanagers
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
        
        return division_codes_for(division_id)
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

    def division_id
        id = NcbiDivision.get_division_id_by_taxon_name(taxon.canonical_name)
        
        return id if id
        
        ## should make multiple searches to find taxon in NCBI Genbank database
        abort "Could not find #{taxon.canonical_name} in NCBI Genbank please use a different taxon" if id.nil?
    end

    def _write_download_info(paths:, success:, download_file_managers:)

        paths.each do |path|
            file = File.open(path, 'w')

            download_file_managers.each_with_index do |download_file_manager, i|
                if path.descend.first.to_s == 'results'
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0
                    
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO)
                else
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0
                    
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO)

                    file.puts 'results:' if i == (download_file_managers.size - 1)
                    file.puts "#{result_file_manager.dir_path.to_s}".prepend(RJUST_LEVEL_ONE) if i == (download_file_managers.size - 1)
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
                file.puts "#{release_info_struct.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0

                sub_directory_success = download_file_manager.status == 'success' ?  true : false
                file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO)
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
            file.puts "#{result_file_manager.dir_path.to_s}".prepend(RJUST_LEVEL_ONE)
        end
    end

    def _classify_downloads(download_file_managers:)
        ## NEXT
        ## here i dont knwo if i want to loop through all the files beforehand? do i need to do that
        ## or is that only good for BOLD?
        ## errors could be hash with file_manager has key then I dont need to pick and remove in run?
        
        erroneous_files_of = Hash.new
        download_file_managers.each do |download_file_manager|
            next unless download_file_manager.status == 'success'
            files = download_file_manager.files_with_name_of(dir: download_file_manager.dir_path)
            
            files.each do |file|
                next unless File.file?(file)

                classifier = NcbiGenbankImporter.new(fast_run: true, markers: markers, file_name: file, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, taxonomy_params: taxonomy_params, region_params: region_params)
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
        DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
        DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump') 

        return download_file_managers
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
