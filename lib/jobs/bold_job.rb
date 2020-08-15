# frozen_string_literal: true

class BoldJob
  attr_reader   :taxon, :markers, :taxonomy, :taxon_name 
  attr_accessor :tried_taxon_ranks, :taxon_rank_to_try, :taxa_names_to_try
  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @taxon_name = taxon.canonical_name
    @markers    = markers
    @taxonomy   = taxonomy

    @tried_taxon_ranks = []
    @taxon_rank_to_try = taxon.taxon_rank
    @taxa_names_to_try = [taxon_name]
  end




  def run2
    _configs.each do |config|
      file_structure = config.file_structure
      file_structure.extend(Helper.constantize("Printing::#{file_structure.class}"))
      file_structure.create_directory

      downloader = config.downloader.new(config: config)
      downloader.extend(Helper.constantize("Printing::#{downloader.class}"))
      
      begin
        downloader.run
      rescue Net::ReadTimeout
        _set_taxa_names_to_try
      end

    end
  end

  def run
    # _configs.each do |config|
      config = BoldConfig.new(name: taxon_name, markers: markers)

      file_structure = config.file_structure
      file_structure.extend(Helper.constantize("Printing::#{file_structure.class}"))
      file_structure.create_directory

      downloader = config.downloader.new(config: config)
      downloader.extend(Helper.constantize("Printing::#{downloader.class}"))



      # tried_taxon_ranks = []
      # taxon_rank_to_try = taxon.taxon_rank
      # taxa_names_to_try = []
      num_rounds = 0

      until num_rounds == 5_000 do
        num_rounds += 1
        if num_rounds == 1
          begin
            downloader.run
          rescue Net::ReadTimeout
            _set_taxa_names_to_try
          end
        else
          p tried_taxon_ranks
          p taxon_rank_to_try
          p taxa_names_to_try
          break
        end
      end
      exit
      tried_taxon_ranks = []
      taxon_rank_to_try = taxon.taxon_rank

      begin
        downloader.run
      # rescue Net::ReadTimeout
      rescue Net::ReadTimeout
        tried_taxon_ranks.push(taxon_rank_to_try)
        last_tried_taxon_rank   = tried_taxon_ranks.last
        index_of_rank           = GbifTaxon.possible_ranks.index(last_tried_taxon_rank)
        # break if index_of_rank  == 0
        index_of_lower_rank     = index_of_rank - 1
        taxon_rank_to_try       = GbifTaxon.possible_ranks[index_of_lower_rank]
        taxa_names              = GbifTaxon.taxa_names_for_rank(taxon: taxon, rank: taxon_rank_to_try)
        _configs(taxa_names: taxa_names)
        puts "Could not download data for #{config.name}, trying lower ranks."

        exit
      end


      # p config
      # config.file_structure.create_directory
      # config.downloader.new(config: config).run
    # end
  end


  private
  def _set_taxa_names_to_try
    @tried_taxon_ranks.push(taxon_rank_to_try)
    last_tried_taxon_rank     = tried_taxon_ranks.last
    index_of_rank             = GbifTaxon.possible_ranks.index(last_tried_taxon_rank)
    # break if index_of_rank  == 0
    index_of_lower_rank       = index_of_rank - 1
    @taxon_rank_to_try        = GbifTaxon.possible_ranks[index_of_lower_rank]
    @taxa_names_to_try        = GbifTaxon.taxa_names_for_rank(taxon: taxon, rank: taxon_rank_to_try)
  end

  def _configs
    configs = []
    taxa_names_to_try.each do |name|
      configs.push(BoldConfig.new(name: name, markers: markers))
    end

    return configs
  end

  def _groups
    taxonomy.taxa_names(taxon)
  end
end
