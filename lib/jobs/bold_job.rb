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
    # _configs.each do |config|
      config = BoldConfig.new(name: taxon_name, markers: markers)

      file_structure = config.file_structure
      file_structure.extend(Helper.constantize("Printing::#{file_structure.class}"))
      file_structure.create_directory

      downloader = config.downloader.new(config: config)
      downloader.extend(Helper.constantize("Printing::#{downloader.class}"))




      tried_taxon_ranks = []
      taxon_rank_to_try = taxon.taxon_rank


      byebug

      begin
        downloader.run
      # rescue Net::ReadTimeout
      rescue Net::ReadTimeout
        tried_taxon_ranks.push(taxon_rank_to_try)
        last_tried_taxon_rank = tried_taxon_ranks.last
        puts last_tried_taxon_rank
        index_of_rank = GbifTaxon.possible_ranks.index(last_tried_taxon_rank)
        p index_of_rank
        # break if index_of_rank == 0
        index_of_lower_rank = index_of_rank - 1
        p index_of_lower_rank
        taxon_rank_to_try = GbifTaxon.possible_ranks[index_of_lower_rank]

        puts "Could not download data for #{config.name}, trying lower ranks."
        # Number of seconds to wait for one block to be read (via one read(2) call). Any number may be used, including Floats for fractional seconds. If the HTTP object cannot read data in this many seconds, it raises a Net::ReadTimeout exception. The default value is 60 seconds.
        p 'exception'
        p 'Net::ReadTimeout'
        exit
      end


      # p config
      # config.file_structure.create_directory
      # config.downloader.new(config: config).run
    # end
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
