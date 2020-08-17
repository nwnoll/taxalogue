# frozen_string_literal: true

class BoldJob
  attr_reader   :taxon, :markers, :taxonomy, :taxon_name 
  # attr_accessor :tried_taxon_ranks, :taxon_rank_to_try, :taxa_names_to_try
  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @taxon_name = taxon.canonical_name
    @markers    = markers
    @taxonomy   = taxonomy

    @tried_taxon_ranks = []
    @taxon_rank_to_try = taxon.taxon_rank
    @taxa_names_to_try = [taxon_name]
  end

  def run
    root_node                           = Tree::TreeNode.new(taxon_name, [taxon, 'pending'])
    
    num_of_ranks                        = GbifTaxon.possible_ranks.size
    reached_family_level                = false
    num_of_ranks.times do |i|
      root_node.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name} - #{node.content.last}" })
      root_node.each do |node|
        next unless node.content.last == 'pending'

        if node.parentage
          parent_names  = []
          node.parentage.each { |parent| parent_names.push(parent.name) } 
          parent_dir    = parent_names.reverse.join('/')
          config        = BoldConfig.new(name: node.name, markers: markers, parent_dir: parent_dir)
        else
          config        = BoldConfig.new(name: node.name, markers: markers)
        end

        file_structure = config.file_structure
        file_structure.extend(Helper.constantize("Printing::#{file_structure.class}"))
        file_structure.create_directory

        downloader = config.downloader.new(config: config)
        downloader.extend(Helper.constantize("Printing::#{downloader.class}"))

        begin
          downloader.run
          p file_structure.file_path
          p File.empty?(file_structure.file_path)

          if File.empty?(file_structure.file_path)
            puts "No records found for #{node.name}."
            node.content[1] = 'failure'
          else
            node.content[1] = 'success'
          end
          root_node.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name} - #{node.content.last}" })
        rescue Net::ReadTimeout
          puts "Download did take too long, most probably #{node.name} has too many records. Trying lower ranks soon."
          node.content[1] = 'failure'
          root_node.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name} - #{node.content.last}" })
        end
      end
      root_node.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name} - #{node.content.last}" })

      break if reached_family_level

      failed_nodes                      = root_node.find_all { |node| node.content.last == 'failure' && node.is_leaf? }
      failed_nodes.each do |failed_node| 
        node_record                     = failed_node.content.first
        node_name                       = failed_node.name
        index_of_rank                   = GbifTaxon.possible_ranks.index(node_record.taxon_rank)
        index_of_lower_rank             = index_of_rank - 1
        reached_family_level            = true if index_of_lower_rank == 2
        taxon_rank_to_try               = GbifTaxon.possible_ranks[index_of_lower_rank]
        taxa_records_and_names_to_try   = GbifTaxon.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        taxa_records_and_names_to_try.each do |record_and_name|
          record                        =  record_and_name.first
          name                          = record_and_name.last
          failed_node                   << Tree::TreeNode.new(name, [record, 'pending'])
        end
      end
    end
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
