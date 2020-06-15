# frozen_string_literal: true

class NcbiGenbankJob
  attr_reader :taxon, :markers, :taxonomy
  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @markers    = markers
    @taxonomy   = taxonomy
  end

  def run
    _configs.each do |config|
      config.file_structure.create_directories
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
    NcbiDivision.get_id(taxon_name: taxon.canonical_name)
  end
end
