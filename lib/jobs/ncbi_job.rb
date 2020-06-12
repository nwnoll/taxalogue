# frozen_string_literal: true

class NcbiJob
  attr_reader :taxon, :markers, :taxonomy, :divisions
  def initialize(taxon:, markers: nil, taxonomy:, divisions:)
    @taxon      = taxon
    @markers    = markers
    @taxonomy   = taxonomy
    @divisions  = divisions

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
    _taxa_names.each do |t|
      configs.push(BoldConfig.new(taxon: t, markers: markers))
    end

    return configs
  end

  def _taxa_names
    taxonomy.taxa_names(taxon)
  end
end
