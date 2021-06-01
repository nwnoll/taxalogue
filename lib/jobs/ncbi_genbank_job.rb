# frozen_string_literal: true

class NcbiGenbankJob
    attr_reader :taxon, :markers, :taxonomy, :result_file_manager, :use_http, :filter_params, :taxonomy_params, :region_params, :params

    FILE_DESCRIPTION_PART = 10

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
        release_info_struct = NcbiDownloadCheckHelper.ask_user_about_download_dirs(params)
        # #<OpenStruct name="release243",
        #     base_dir=#<Pathname:fm_data/NCBIGENBANK/release243>,
        #     success=true,
        #     dirs_for_code={"inv"=>#<Pathname:fm_data/NCBIGENBANK/release243/inv>},
        #     missing_divisions=[],
        #     has_all_divisions=true,
        #     is_current_release=true>

        already_downloaded_dir = release_info_struct.base_dir if release_info_struct

        ## NEXT

        if already_downloaded_dir
          begin
            fm_from_md_name         = already_downloaded_dir + '.download_file_managers.dump'
            fm_from_md              = Marshal.load(File.open(fm_from_md_name, 'rb').read)
            download_file_managers  = fm_from_md
            _create_download_info_for_result_dir(already_downloaded_dir)
            # if the files will  ot be found it cannot open them and an error is thrown
            # should ich catch it beforehand or just use my STandarError catching? bat practice?
          rescue StandardError => e
            byebug
            puts "Directory could not be used, starting download"
            sleep 2

            download_file_managers = download_files
            DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
            DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
          end
        else

          download_file_managers  = download_files
          DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
          DownloadCheckHelper.write_marshal_file(dir: NcbiGenbankConfig::DOWNLOAD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
        end

        ## NEXT TODO:
        # Problem here is that I dont get erroneous_files if the download file manager already stated
        # the download was not successfull,
        # this is good  since I dont want to break all the upcioming bOLD or GBOL dowloads, but it is also bad
        # since then it wont download anything? another thing is even if I want to download the files,
        # then I dont know which ones since ther will be no files in the array
        # dont know how i should do it atm...
        erroneous_files_of = _classify_downloads(download_file_managers: download_file_managers)
        p erroneous_files_of

        p 'here'
        if erroneous_files_of.empty?
            puts "no errors found"
        else
            ## I could use download_file_managers and the errors array to download the erroneous files again?

            puts "got some errors"
            p erroneous_files_of
            byebug
            download_file_managers = download_failed_files(download_file_managers: download_file_managers, erroneous_files_of: erroneous_files_of)
           
        end

        return result_file_manager
        # _merge_results
    end

    def download_files
        ## TODO:
        ## maybe switch NcbiApi if taxon is of rank family?
        ## highert taxa might give an incomplete download
        ## it might be annoying if there will be searches
        ## for quite small taxa and the prog tries to download
        ## several gigabyte of data
        fmanagers = []
        @root_download_dir = _get_release_dir

        _configs.each do |config|
            file_manager = config.file_manager
            file_manager.create_dir
            
            ## TODO: uncomment again, this is because there are some ports not open at the museum...
            ## This might be the case for other institutions too
            ## if ftp is usdownload_did_failed then I might catch that exception and try to download via http
            
            downloader          = config.downloader.new(config: config)
            download_did_fail   = false

            begin
                downloader.run
            rescue SocketError
                download_did_fail = true
            rescue StandardError
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
        ## problem is should i use basedir? 
        ## ord dir_path in general it is easier to jsut use basedir NCBIGENBANK/relase242
        ## but if i want to distinguish between different division downloads i need it separately...
        _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: fmanagers)

        return fmanagers
    end

    def download_failed_files(download_file_managers:, erroneous_files_of:)
        @root_download_dir = _get_release_dir unless @root_download_dir

        # files_for_group = _get_files_for_group(erroneous_files_of)

        # files_for_group.each do |key, value|
        #     download_file_manager = download_file_managers.select! { |fm| fm.name == key }.first
        #     download_file_managers.reject! { |fm| fm.name == key }
            
        #     config = download_file_manager.config
        #     downloader = config.downloader.new(config: config)

        #     download_did_fail   = false

        #     begin
        #         downloader.run(files_to_download: value)
        #     rescue SocketError
        #         download_did_fail = true
        #     rescue StandardError
        #         download_did_fail = true
        #     end

        #     files = download_file_manager.files_of(dir: download_file_manager.dir_path)
        #     files.each do |file|
        #         if File.empty?(file)
        #             download_did_fail = true
        #             break
        #         end
        #     end
        #     download_file_manager.status = download_did_fail ? 'failure' : 'success'
            
        #     download_file_managers.push(download_file_manager)
        # end


        erroneous_files_of.each do |download_file_manager, erroneous_files|
            
            download_file_managers.reject! { |fm| fm == download_file_manager }

            config = download_file_manager.config
            downloader = config.downloader.new(config: config)

            download_did_fail   = false

            begin
                downloader.run(files_to_download: erroneous_files)
            rescue SocketError
                download_did_fail = true
            rescue StandardError
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

    private

    def _create_download_info_for_result_dir(already_downloaded_dir)
        data_dl_info_public_name = already_downloaded_dir + 'download_info.txt'
        data_dl_info_hidden_name = already_downloaded_dir + '.download_info.txt'

        result_dl_info_public_name = result_file_manager.dir_path + 'download_info.txt'
        result_dl_info_hidden_name = result_file_manager.dir_path + '.download_info.txt'

        dl_info_public = File.open(data_dl_info_public_name).read
        dl_info_hidden = File.open(data_dl_info_hidden_name).read

        dl_info_public.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
        dl_info_hidden.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
        
        File.open(result_dl_info_public_name, 'w') { |f| f.write(dl_info_public) }
        File.open(result_dl_info_hidden_name, 'w') { |f| f.write(dl_info_hidden) }
    end

    def _write_download_info(paths:, success:, download_file_managers:)
        download_file_managers.each do |download_file_manager|
            puts "download_file_manager:"
            pp download_file_manager
            puts
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
    end

    def _configs
        configs = []
        release_dir = _get_release_dir
        _groups.each do |name|
            configs.push(NcbiGenbankConfig.new(name: name, markers: markers, use_http: use_http, parent_dir: release_dir))
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

    def _write_result_files(fmanagers:)
        fmanagers.each do |root_dir|
            merged_download_file_name  = root_dir.dir_path + "merged.gz"
            download_info_file    = File.open(root_dir.dir_path + "download_info.tsv", 'w') 
            download_successes    = fmanagers.select { |m| m.status == 'success' }

            OutputFormat::MergedGenbankDownload.write_to_file(file_name: merged_download_file_name, data: download_successes, header_length: FILE_DESCRIPTION_PART, include_header: false)
            OutputFormat::DownloadInfo.write_to_file(file: download_info_file, fmanagers: fmanagers)
        end
    end

    def _classify_downloads(download_file_managers:)
        ## NEXT
        ## here i dont knwo if i want to loop through all the files beforehand? do i need to do that
        ## or is that only good for BOLD?
        ## errors could be hash with file_manager has key then I dont need to pick and remove in run?
        
        erroneous_files_of = Hash.new { |h, k| h[k] =  [] }
        download_file_managers.each do |download_file_manager|
            byebug
            next unless download_file_manager.status == 'success'
            files = download_file_manager.files_with_name_of(dir: download_file_manager.dir_path)
            
            files.each do |file|
                next unless File.file?(file)

                classifier = NcbiGenbankImporter.new(fast_run: true, markers: markers, file_name: file, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, taxonomy_params: taxonomy_params, region_params: region_params)
                erroneous_files = classifier.run ## result_file_manager creates new files and will push those into internal array
                erroneous_files_of[download_file_manager].push(erroneous_files) if erroneous_files.any?
            end
        end

        return erroneous_files_of
    end

    def _merge_results
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
    end

    def _get_release_dir
        release_number = NcbiDownloadCheckHelper.get_current_genbank_release_number
        name = "release#{release_number}"
        
        return Pathname.new(name)
    end
end
