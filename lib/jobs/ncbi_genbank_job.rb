# frozen_string_literal: true

class NcbiGenbankJob
  attr_reader :taxon, :markers, :taxonomy

  FILE_DESCRIPTION_PART = 10

  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @markers    = markers
    @taxonomy   = taxonomy
  end

  def run
    ## maybe switch NcbiApi if taxon is of rank family?
    ## highert taxa might give an incomplete download
    ## it might be annoying if there will be searches
    ## for quite small taxa and the prog tries to download
    ## several gigabyte of data
    fmanagers = []

    _configs.each do |config|
      file_manager        = config.file_manager
      file_manager.create_dir

      downloader          = config.downloader.new(config: config)
      downloader.run

      files               = file_manager.files_of(dir: file_manager.dir_path)
      did_download_fail   = false
      files.each { |file| download_did_fail = true; break if File.empty?(file) } 
      file_manager.status = did_download_fail ? 'failure' : 'success'
      fmanagers.push(file_manager)
    end
    _write_result_files(fmanagers: fmanagers)
  end


  private
  def _configs
    configs = []
    _groups.each do |name|
      configs.push(NcbiGenbankConfig.new(name: name, markers: markers))
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
end
