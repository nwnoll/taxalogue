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
      _download_progress_report(root_node)
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
          _download_progress_report(root_node)
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
        _download_progress_report(root_node)
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

  def _download_progress_report(root_node)
    system("clear") || system("cls")
    puts
    puts @pending.ljust(20) + "waits until a downloader is avalaible"
    puts @loading.ljust(20) + "downloads records"
    puts @failure.ljust(20) + "download was not successful, often due to too many records, tries lower ranks soon"
    puts @success.ljust(20) + "download was successful"
    puts
    root_node.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" })
  end
end
