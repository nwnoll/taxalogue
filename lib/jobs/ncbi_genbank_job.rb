# frozen_string_literal: true

class NcbiGenbankJob
  attr_reader :taxon, :markers, :taxonomy
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

    _configs.each do |config|
      # config.file_structure.create_directory
      config.file_manager.create_dir
      config.downloader.new(config: config).run
    end
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
end
