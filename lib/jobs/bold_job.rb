# frozen_string_literal: true

class BoldJob
  attr_reader :taxon, :markers, :taxonomy, :taxon_name
  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @taxon_name = taxon.canonical_name
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
    _taxa_names.each do |name|
      configs.push(BoldConfig.new(taxon_name: name, markers: markers))
    end

    return configs
  end

  def _taxa_names
    taxonomy.taxa_names(taxon)
  end
end
