# frozen_string_literal: true

class BoldJob
  attr_reader   :taxon, :markers, :taxonomy, :taxon_name 
  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @taxon_name = taxon.canonical_name
    @markers    = markers
    @taxonomy   = taxonomy

    @pending = Pastel.new.white.on_yellow('pending')
    @failure = Pastel.new.white.on_red('failure')
    @success = Pastel.new.white.on_green('success')
    @loading = Pastel.new.white.on_blue('loading')
  end

  def run
    root_node                           = Tree::TreeNode.new(taxon_name, [taxon, @pending])
    
    num_of_ranks                        = GbifTaxon.possible_ranks.size
    reached_family_level                = false
    num_of_ranks.times do |i|
      _download_progress_report(root_node: root_node, rank_level: i)
      Parallel.map(root_node.entries, in_threads: 5) do |node|
        next unless node.content.last == @pending
        puts

        if node.parentage
          parent_names  = []
          node.parentage.each { |parent| parent_names.push(parent.name) } 
          parent_dir    = parent_names.reverse.join('/')
          config        = BoldConfig.new(name: node.name, markers: markers, parent_dir: parent_dir)
        else
          config        = BoldConfig.new(name: node.name, markers: markers)
        end

        file_structure = config.file_structure
        # file_structure.extend(Helper.constantize("Printing::#{file_structure.class}"))
        file_structure.create_directory

        downloader = config.downloader.new(config: config)
        # downloader.extend(Helper.constantize("Printing::#{downloader.class}"))

        begin
          node.content[1] = @loading
          _download_progress_report(root_node: root_node, rank_level: i)
          downloader.run
          if File.empty?(file_structure.file_path)
            # puts "No records found for #{node.name}."
            node.content[1] = @failure
          else
            node.content[1] = @success
          end
        rescue Net::ReadTimeout
          # puts "Download did take too long, most probably #{node.name} has too many records. Trying lower ranks soon."
          node.content[1] = @failure
        end
        _download_progress_report(root_node: root_node, rank_level: i)
      end
      
      break if reached_family_level

      failed_nodes                      = root_node.find_all { |node| node.content.last == @failure && node.is_leaf? }
      failed_nodes.each do |failed_node| 
        node_record                     = failed_node.content.first
        node_name                       = failed_node.name
        index_of_rank                   = GbifTaxon.possible_ranks.index(node_record.taxon_rank)
        index_of_lower_rank             = index_of_rank - 1
        reached_family_level            = true if index_of_lower_rank == 2
        taxon_rank_to_try               = GbifTaxon.possible_ranks[index_of_lower_rank]
        taxa_records_and_names_to_try   = GbifTaxon.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        taxa_records_and_names_to_try.each do |record_and_name|
          record                        = record_and_name.first
          name                          = record_and_name.last
          failed_node                   << Tree::TreeNode.new(name, [record, @pending])
        end
      end
    end
  end

  def _download_progress_report(root_node:, rank_level:)
    root_copy = root_node.detached_subtree_copy 
    system("clear") || system("cls")
    puts
    # root_node.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" }) if rank_level < 3
    nodes_currently_loading = root_copy.find_all { |node| node.content.last == @loading && node.is_leaf? }
    return if nodes_currently_loading.nil?
    if nodes_currently_loading.size == 1
      root_copy.print_tree(level = root_copy.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" })
      return
    end
    already_printed_parents = []
    nodes_currently_loading.each do |loading_node|
      not_loading_nodes = loading_node.parent.find_all { |node| node.content.last != @loading && node.is_leaf?}
      not_loading_nodes.each do |not_loading_node|
        loading_node.parent.remove!(not_loading_node)
      end
      puts "currently loading:"
      loading_node.parent.print_tree(level = loading_node.parent.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" }) unless already_printed_parents.include?(loading_node.parent.name)
      already_printed_parents.push(loading_node.parent.name)
      # puts "#{loading_node.name}".ljust(30) + " #{loading_node.content.last}"
    end
    # puts
    # root_copy.print_tree(level = root_copy.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" })

    
    # if rank_level > 1
    #   puts
    #   puts "currently loading:"
    #   nodes_currently_loading.each do |loading_node|
    #     puts "#{loading_node.name}".ljust(30) + " #{loading_node.content.last}"
    #   end
    # elsif rank_level > 2
    #   puts
    #   puts "currently loading:"
    #   already_printed_parents = []
    #   nodes_currently_loading.each do |loading_node|
    #     # if  already_printed_parents.include?(loading_node.parent.name)
    #       not_loading_nodes = loading_node.parent.find_all { |node| node.content.last != @loading && node.is_leaf?}
    #       not_loading_nodes.each do |not_loading_node|
    #         loading_node.parent.remove(not_loading_node)
    #       end
    #       loading_node.parent.print_tree(level = loading_node.parent.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" }) 
    #     #   already_printed_parents.push(loading_node.parent.name)
    #     # else
    #     #   loading_node.parent.print_tree(level = loading_node.parent.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" }) 
    #     #   already_printed_parents.push(loading_node.parent.name)
    #     # end

    #     # puts "#{loading_node.parent.name}".ljust(30) + " #{loading_node.parent.content.last}" unless already_printed_parents.include?(loading_node.parent.name)
    #     # already_printed_parents.push(loading_node.parent.name)
    #     # puts "#{loading_node.name}".ljust(30) + " #{loading_node.content.last}"
    #   end
    # end
    puts
    puts @pending.ljust(20) + "waits until a downloader is avalaible"
    puts @loading.ljust(20) + "downloads records"
    puts @failure.ljust(20) + "download was not successful, often due to too many records, tries lower ranks soon"
    puts @success.ljust(20) + "download was successful"
    puts
  end
end
