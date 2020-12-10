# frozen_string_literal: true

class BoldJob
  attr_reader   :taxon, :markers, :taxonomy, :taxon_name , :result_file_manager

  HEADER_LENGTH = 1

  def initialize(taxon:, markers: nil, taxonomy:, result_file_manager:)
    @taxon                = taxon
    @taxon_name           = taxon.canonical_name
    @markers              = markers
    @taxonomy             = taxonomy
    @result_file_manager  = result_file_manager

    @pending = Pastel.new.white.on_yellow('pending')
    @failure = Pastel.new.white.on_red('failure')
    @success = Pastel.new.white.on_green('success')
    @loading = Pastel.new.white.on_blue('loading')
    @loading_color_char_num = (@loading.size) -'loading'.size
  end

  def run
    download_file_managers = download_files

    _classify_downloads(download_file_managers: download_file_managers)
    
    return result_file_manager
    # _write_result_files(root_node: root_node, fmanagers: fmanagers)
  end

  def download_files
    root_node                           = Tree::TreeNode.new(taxon_name, [taxon, @pending])
    
    num_of_ranks                        = GbifTaxonomy.possible_ranks.size
    reached_family_level                = false
    fmanagers                           = []
    
    num_of_ranks.times do |i|
      
      _print_download_progress_report(root_node: root_node, rank_level: i)
      
      Parallel.map(root_node.entries, in_threads: 5) do |node|
        next unless node.content.last == @pending

        config = _create_config(node: node)

        file_manager = config.file_manager
        file_manager.create_dir

        downloader = config.downloader.new(config: config)
        # downloader.extend(Helper.constantize("Printing::#{downloader.class}"))

        begin
          node.content[1] = @loading
          file_manager.status = 'loading'
          _print_download_progress_report(root_node: root_node, rank_level: i)
          downloader.run
          if File.empty?(file_manager.file_path)
            # puts "No records found for #{node.name}."
            node.content[1] = @failure
            file_manager.status = 'failure'
          else
            node.content[1] = @success
            file_manager.status = 'success'
          end
        rescue Net::ReadTimeout
          # puts "Download did take too long, most probably #{node.name} has too many records. Trying lower ranks soon."
          node.content[1] = @failure
          file_manager.status = 'failure'
        end

        fmanagers.push(file_manager)
        _print_download_progress_report(root_node: root_node, rank_level: i)
      end
      
      break if reached_family_level
      break if i == 1

      failed_nodes                      = root_node.find_all { |node| node.content.last == @failure && node.is_leaf? }
      failed_nodes.each do |failed_node| 
        node_record                     = failed_node.content.first
        node_name                       = failed_node.name
        index_of_rank                   = GbifTaxonomy.possible_ranks.index(node_record.taxon_rank)
        index_of_lower_rank             = index_of_rank - 1
        reached_family_level            = true if index_of_lower_rank == 2
        taxon_rank_to_try               = GbifTaxonomy.possible_ranks[index_of_lower_rank]
        taxa_records_and_names_to_try   = GbifTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        next if taxa_records_and_names_to_try.nil?
        taxa_records_and_names_to_try.each do |record_and_name|
          record                        = record_and_name.first
          name                          = record_and_name.last
          failed_node                   << Tree::TreeNode.new(name, [record, @pending])
        end
      end
    end

    return fmanagers
  end

  def _print_download_progress_report(root_node:, rank_level:)
    root_copy = root_node.detached_subtree_copy

    system("clear") || system("cls")
    puts

    nodes_currently_loading = root_copy.find_all { |node| node.content.last == @loading && node.is_leaf? }
    return if nodes_currently_loading.nil?
    
    if rank_level <= 1
      root_copy.print_tree(level = root_copy.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" })
      _print_legend
      return
    end

    already_printed_parents = []
    loading_parent_nodes    = []
    nodes_currently_loading.each { |node| loading_parent_nodes.push(node.parentage); loading_parent_nodes.flatten! }
    
    root_copy.print_tree(level = root_copy.node_depth, max_depth = 1, block = lambda { |node, prefix| puts loading_parent_nodes.include?(node) ? "#{prefix} #{Pastel.new.white.on_blue(node.name)}".ljust(30 + @loading_color_char_num) + " #{node.content.last}" : "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" })
    
    puts
    puts "currently loading:"
    nodes_currently_loading.each do |loading_node|
      not_loading_nodes = loading_node.parent.find_all { |node| node.content.last != @loading && node.is_leaf? }
      not_loading_nodes.each do |not_loading_node|
        loading_node.parent.remove!(not_loading_node)
      end

      if already_printed_parents.include?(loading_node.parent.name)
        next
      else
        loading_node.parent.print_tree(level = loading_node.parent.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content.last}" })
      end

      already_printed_parents.push(loading_node.parent.name)
    end
    _print_legend
  end

  def _print_legend
    puts
    puts @pending.ljust(20) + "waits until a downloader is avalaible"
    puts @loading.ljust(20) + "downloads records"
    puts @failure.ljust(20) + "download was not successful, often due to too many records, tries lower ranks soon"
    puts @success.ljust(20) + "download was successful"
    puts
  end

  def _create_config(node:)
    if node.parentage
      parent_names  = []
      node.parentage.each { |parent| parent_names.push(parent.name) } 
      parent_dir    = parent_names.reverse.join('/')
      config        = BoldConfig.new(name: node.name, markers: markers, parent_dir: parent_dir)
    else
      config        = BoldConfig.new(name: node.name, markers: markers)
    end
  end

  def _write_result_files(root_node:, fmanagers:)
    root_dir              = fmanagers.select { |m| m.name == root_node.name }.first
    merged_download_file  = File.open(root_dir.dir_path + "#{root_dir.name}_merged.tsv", 'w') 
    download_info_file    = File.open(root_dir.dir_path + "#{root_dir.name}_download_info.tsv", 'w') 
    download_successes    = fmanagers.select { |m| m.status == 'success' }

    OutputFormat::MergedBoldDownload.write_to_file(file: merged_download_file, data: download_successes, header_length: HEADER_LENGTH, include_header: true)
    OutputFormat::DownloadInfo.write_to_file(file: download_info_file, fmanagers: fmanagers)
  end

  def _classify_downloads(download_file_managers:)
    download_file_managers.each do |download_file_manager|
      next unless download_file_manager.status == 'success'
      next unless File.file?(download_file_manager.file_path)

	    bold_classifier   = BoldImporter.new(fast_run: false, file_name: download_file_manager.file_path, query_taxon_object: taxon, file_manager: result_file_manager)
      bold_classifier.run ## result_file_manager creates new files and will push those into internal array
    end
  end

  def _merge_results
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
  end
end
