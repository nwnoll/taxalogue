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
      file_structure = config.file_structure
      file_structure.extend(constantize("Printing::#{file_structure.class}"))
      file_structure.create_directory

      downloader = config.downloader.new(config: config)
      downloader.extend(constantize("Printing::#{downloader.class}"))
      downloader.run


      # p config
      # config.file_structure.create_directory
      # config.downloader.new(config: config).run
    end
  end


  private
  def _configs
    configs = []
    _groups.each do |name|
      configs.push(BoldConfig.new(name: name, markers: markers))
    end

    return configs
  end

  def _groups
    taxonomy.taxa_names(taxon)
  end
end
