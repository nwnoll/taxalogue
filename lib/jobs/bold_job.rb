# frozen_string_literal: true

# /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/resolv-replace.rb:25:in `initialize': execution expired (Net::OpenTimeout)
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/resolv-replace.rb:25:in `initialize'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/net/http.rb:987:in `open'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/net/http.rb:987:in `block in connect'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/timeout.rb:107:in `timeout'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/net/http.rb:985:in `connect'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/net/http.rb:970:in `do_start'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/net/http.rb:959:in `start'
# 	from /home/nnoll/.rvm/rubies/ruby-3.0.0/lib/ruby/3.0.0/net/http.rb:621:in `start'
# 	from /home/nnoll/phd/db_merger/lib/downloaders/http_downloader.rb:20:in `run'
# 	from /home/nnoll/phd/db_merger/lib/jobs/bold_job.rb:63:in `block (2 levels) in download_files'
# 	from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/parallel-1.19.2/lib/parallel.rb:508:in `call_with_index'
# 	from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/parallel-1.19.2/lib/parallel.rb:361:in `block (2 levels) in work_in_threads'
# 	from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/parallel-1.19.2/lib/parallel.rb:519:in `with_instrumentation'
# 	from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/parallel-1.19.2/lib/parallel.rb:360:in `block in work_in_threads'
# 	from /home/nnoll/.rvm/gems/ruby-3.0.0/gems/parallel-1.19.2/lib/parallel.rb:211:in `block (4 levels) in in_threads'




class BoldJob
  attr_reader   :taxon, :markers, :taxonomy, :taxon_name , :result_file_manager, :filter_params, :try_synonyms, :taxonomy_params, :region_params

  HEADER_LENGTH = 1

  def initialize(taxon:, markers: nil, taxonomy:, result_file_manager:, filter_params: nil, try_synonyms: false, taxonomy_params:, region_params: nil)
    @taxon                = taxon
    @taxon_name           = taxon.canonical_name
    @markers              = markers
    @taxonomy             = taxonomy
    @result_file_manager  = result_file_manager
    @filter_params        = filter_params
    @try_synonyms         = try_synonyms
    @taxonomy_params      = taxonomy_params
    @region_params        = region_params

    @pending = Pastel.new.white.on_yellow('pending')
    @failure = Pastel.new.white.on_red('failure')
    @success = Pastel.new.white.on_green('success')
    @loading = Pastel.new.white.on_blue('loading')
    @loading_color_char_num = (@loading.size) -'loading'.size

  end

  def run
    download_file_managers = download_files

    _classify_downloads(download_file_managers: download_file_managers)
    # _classify_downloads(download_file_managers: nil)
    
    return result_file_manager
    # _write_result_files(root_node: root_node, fmanagers: fmanagers)
  end

  def download_files
    root_node                           = Tree::TreeNode.new(taxon_name, [taxon, @pending])
    ## TODO: same for NcbiTaxonomy
    num_of_ranks                        = GbifTaxonomy.possible_ranks.size
    reached_family_level                = false
    reached_genus_level                = false
    fmanagers                           = []
    num_threads = 2
    
    num_of_ranks.times do |i|
      
      _print_download_progress_report(root_node: root_node, rank_level: i)
      
      Parallel.map(root_node.entries, in_threads: num_threads) do |node|
        next unless node.content.last == @pending

        config = _create_config(node: node)

        file_manager = config.file_manager
        file_manager.create_dir

        downloader = config.downloader.new(config: config)
        # downloader.extend(MiscHelper.constantize("Printing::#{downloader.class}"))

        begin
          node.content[1] = @loading
          file_manager.status = 'loading'
          _print_download_progress_report(root_node: root_node, rank_level: i)
          downloader.run
          if File.empty?(file_manager.file_path)
            if try_synonyms
              synonym_file_manager = _download_synonym(node: node)
              if synonym_file_manager && synonym_file_manager.status == 'success'
                file_manager = synonym_file_manager 
                node.content[1] = @success
              else
                node.content[1] = @failure
                file_manager.status = 'failure'
              end
            else
              node.content[1] = @failure
              file_manager.status = 'failure'
            end
          else
            if File.open(file_manager.file_path, &:gets) =~ /<!DOCTYPE html>/
              node.content[1] = @failure
              file_manager.status = 'failure'
            else
              node.content[1] = @success
              file_manager.status = 'success'
            end
          end
        rescue Net::ReadTimeout
          node.content[1] = @failure
          file_manager.status = 'failure'
        end

        fmanagers.push(file_manager)
        _print_download_progress_report(root_node: root_node, rank_level: i)
      end
      
      break if reached_family_level
      # break if i == 2

      failed_nodes = root_node.find_all { |node| node.content.last == @failure && node.is_leaf? }
      failed_nodes.each do |failed_node|
        node_record                     = failed_node.content.first
        node_name                       = failed_node.name
        index_of_rank                   = GbifTaxonomy.possible_ranks.index(node_record.taxon_rank)
        index_of_lower_rank             = index_of_rank - 1
        # reached_family_level            = true if index_of_lower_rank == 2
        reached_genus_level             = true if index_of_lower_rank == 1
        taxon_rank_to_try               = GbifTaxonomy.possible_ranks[index_of_lower_rank]
        
        taxa_records_and_names_to_try = nil
        if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
          taxa_records_and_names_to_try   = GbifTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        elsif taxonomy_params[:ncbi]
          taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        else
          taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
        end

        next if taxa_records_and_names_to_try.nil?
        added_names = []
        taxa_records_and_names_to_try.each do |record_and_name|

          record  = record_and_name.first
          name    = record_and_name.last
          
          next if TaxonHelper.is_extinct?(name)
          next if added_names.include?(name) # prevent breaking if name occurs multiple times maybe due to wrong backbone

          failed_node << Tree::TreeNode.new(name, [record, @pending])
          added_names.push(name)
        end
      end
    end

    _write_result_files(root_node: root_node, fmanagers: fmanagers)


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
      parent_dir    = _get_parentage_as_dir_structure(node)
      config        = BoldConfig.new(name: node.name, markers: markers, parent_dir: parent_dir)
    else
      config        = BoldConfig.new(name: node.name, markers: markers)
    end
  end

  def _get_parentage_as_dir_structure(node)
    if node.parentage
      parent_names  = []
      node.parentage.each { |parent| parent_names.push(parent.name) } 
      parent_dir    = parent_names.reverse.join('/')
      
      return parent_dir
    end
  end

  ## TODO: same for NcbiTaxonomy
    def _download_synonym(node:)
        syn = Synonym.new(accepted_taxon: node.content.first, sources: [GbifTaxonomy])
        file_manager = nil

        syn.synonyms_of_taxonomy.each do |taxonomy, synonyms|
            synonyms.each do |synonym|
                parent_dir      = _get_parentage_as_dir_structure(node)
                synonym_config  = BoldConfig.new(name: synonym.canonical_name, markers: markers, parent_dir: parent_dir)
                
                file_manager    = synonym_config.file_manager
                file_manager.create_dir
                
                synonym_downloader  = synonym_config.downloader.new(config: synonym_config)
                
                begin
                    synonym_downloader.run
                    if File.empty?(file_manager.file_path)
                        file_manager.status = 'failure'
                    else
                        file_manager.status = 'success'
                        break
                    end
                rescue Net::ReadTimeout
                    file_manager.status = 'failure'
                end
            end
        end

        if file_manager && file_manager.status == 'success'
            return file_manager
        else  
            return nil
        end
    end

  def _write_result_files(root_node:, fmanagers:)
    root_dir              = fmanagers.select { |m| m.name == root_node.name }.first
    # merged_download_file  = File.open(root_dir.dir_path + "#{root_dir.name}_merged.tsv", 'w') 
    download_info_file    = File.open(root_dir.dir_path + "#{root_dir.name}_download_info.tsv", 'w') 
    # download_successes    = fmanagers.select { |m| m.status == 'success' }

    # OutputFormat::MergedBoldDownload.write_to_file(file: merged_download_file, data: download_successes, header_length: HEADER_LENGTH, include_header: true)
    OutputFormat::DownloadInfo.write_to_file(file: download_info_file, fmanagers: fmanagers)
  end

  def _classify_downloads(download_file_managers:)
    # bold_classifier   = BoldImporter.new(fast_run: false, file_name: Pathname.new('/home/nnoll/phd/trait_db/notes/coll.tsv'), query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, markers: markers, taxonomy_params: taxonomy_params, region_params: region_params)
    # bold_classifier.run ## result_file_manager creates new files and will push those into internal array
    
    download_file_managers.each do |download_file_manager|
      next unless download_file_manager.status == 'success'
      next unless File.file?(download_file_manager.file_path)

	    bold_classifier   = BoldImporter.new(fast_run: false, file_name: download_file_manager.file_path, query_taxon_object: taxon, file_manager: result_file_manager, filter_params: filter_params, markers: markers, taxonomy_params: taxonomy_params, region_params: region_params)
      bold_classifier.run ## result_file_manager creates new files and will push those into internal array
    end
  end

  def _merge_results
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
    FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
  end
end
