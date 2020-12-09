# frozen_string_literal: true

class NcbiGenbankJob
  attr_reader :taxon, :markers, :taxonomy, :result_file_manager, :use_http

  FILE_DESCRIPTION_PART = 10

  def initialize(taxon:, markers: nil, taxonomy:, result_file_manager:, use_http: false)
    @taxon                = taxon
    @markers              = markers
    @taxonomy             = taxonomy
    @result_file_manager  = result_file_manager
    @use_http             = use_http
  end

  def run
    # _write_result_files(fmanagers: fmanagers)
    download_file_managers = download_files
    _classify_downloads(download_file_managers: download_file_managers)

    return result_file_manager
    # _merge_results
  end

  def download_files
     ## maybe switch NcbiApi if taxon is of rank family?
    ## highert taxa might give an incomplete download
    ## it might be annoying if there will be searches
    ## for quite small taxa and the prog tries to download
    ## several gigabyte of data
    fmanagers = []

    _configs.each do |config|
      file_manager        = config.file_manager
      file_manager.create_dir
      
      ## TODO: uncomment again, this is because there are some ports not open at the museum...
      ## This might be the case for other institutions too
      ## if ftp is used then I might catch that exception and try to download via http
      
      # downloader          = config.downloader.new(config: config)
      # downloader.run

      files               = file_manager.files_of(dir: file_manager.dir_path)
      did_download_fail   = false
      files.each { |file| download_did_fail = true; break if File.empty?(file) } 
      file_manager.status = did_download_fail ? 'failure' : 'success'
      fmanagers.push(file_manager)
    end

    return fmanagers
  end


  private
  def _configs
    configs = []
    _groups.each do |name|
      configs.push(NcbiGenbankConfig.new(name: name, markers: markers, use_http: use_http))
    end

    return configs
  end

  def _groups
    return division_codes_for(animal_divisions) if taxon.canonical_name  == 'Animalia'
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
    id = NcbiDivision.get_id(taxon_name: taxon.canonical_name)
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

	      classifier = NcbiGenbankImporter.new(fast_run: true, markers: markers, file_name: file, query_taxon_object: taxon, file_manager: result_file_manager)
        classifier.run ## result_file_manager creates new files and will push those into internal array
      end
    end
  end

  def _merge_results
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
  end
end
