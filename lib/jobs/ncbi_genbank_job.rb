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
    already_downloaded_dir = NcbiDownloadCheckHelper.ask_user_about_download_dirs(params)
    
    # if already_downloaded_dir
    #   begin
    #     fm_from_md_name         = already_downloaded_dir + '.download_file_managers.dump'
    #     fm_from_md              = Marshal.load(File.open(fm_from_md_name, 'rb').read)
    #     download_file_managers  = fm_from_md

    #     _create_download_info_for_result_dir(already_downloaded_dir)
    #   rescue StandardError
    #     puts "Directory could not be used, starting download"
    #     sleep 2

    #     download_file_managers = download_files
    #     DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
    #     DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
    #   end
    # else

    #   download_file_managers  = download_files
    #   DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
    #   DownloadCheckHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
    # end



    # _write_result_files(fmanagers: fmanagers)
    download_file_managers = download_files
    # exit
    _classify_downloads(download_file_managers: download_file_managers)

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

    _configs.each do |config|
      file_manager = config.file_manager
      file_manager.create_dir
      
      ## TODO: uncomment again, this is because there are some ports not open at the museum...
      ## This might be the case for other institutions too
      ## if ftp is used then I might catch that exception and try to download via http
      
      downloader          = config.downloader.new(config: config)
      downloader.run

      files               = file_manager.files_of(dir: file_manager.dir_path)
      did_download_fail   = false
      files.each { |file| download_did_fail = true; break if File.empty?(file) } 
      file_manager.status = did_download_fail ? 'failure' : 'success'
      fmanagers.push(file_manager)
    end

    success = fmanagers.all? { |fm| fm.status == 'success'}
    dl_path_public = Pathname.new(file_manager.dir_path + DOWNLOAD_INFO_NAME)
    dl_path_hidden = Pathname.new(file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
    rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
    rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
    root_download_dir
    _write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: fmanagers)

    return fmanagers
  end

  private
  def _write_download_info(paths:, success:, download_file_managers:)

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
    download_file_managers.each do |download_file_manager|
      next unless download_file_manager.status == 'success'
      files = download_file_manager.files_with_name_of(dir: download_file_manager.dir_path)
      
      files.each do |file|
        next unless File.file?(file)

	      classifier = NcbiGenbankImporter.new(fast_run: true, markers: markers, file_name: file, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, taxonomy_params: taxonomy_params, region_params: region_params)
        classifier.run ## result_file_manager creates new files and will push those into internal array
      end
    end
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
