# frozen_string_literal: true

class BoldJob
    attr_reader :taxon, :markers, :taxon_name, :result_file_manager, :try_synonyms, :taxonomy_params, :params, :download_only, :classify_only, :classify_dir, :num_threads

    HEADER_LENGTH = 1
    BOLD_DIR = Pathname.new('downloads/BOLD')
    DOWNLOAD_INFO_NAME = "bold_download_info.txt"
    DOWNLOAD_INFO_TREE_NAME = "bold_download_tree_info.txt"

    def initialize(result_file_manager:, try_synonyms: false, params: nil)
        @result_file_manager  = result_file_manager
        @try_synonyms         = try_synonyms
        @params               = params
        @taxon                = params[:taxon_object]
        @taxon_name           = taxon.canonical_name
        @markers              = params[:marker_objects]
        @taxonomy_params      = params[:taxonomy]
        @download_only        = params[:download][:bold] || params[:download][:all]
        @classify_only        = params[:classify][:bold] || params[:classify][:all]
        @classify_dir         = params[:classify][:bold_dir]
        @num_threads          = params[:num_threads] < 0 ? 5 : params[:num_threads]
        @root_download_dir    = nil

        @pending = Pastel.new.white.on_yellow('pending')
        @failure = Pastel.new.white.on_red('failure')
        @success = Pastel.new.white.on_green('success')
        @loading = Pastel.new.white.on_blue('loading')
        @loading_color_char_num = (@loading.size) -'loading'.size

    end

    def run(already_downloaded_dir)
        download_file_managers = _get_download_file_managers_from_already_downloaded_dir(already_downloaded_dir)
        ## TODO:
        # Problem could be if the program chose a higher taxon
        # and the query taxon had no success
        # does it choose that dir, in general only dirs are selected that are successfull
        if download_file_managers.empty?
            if classify_only
                MiscHelper.message_for_missing_download_file_managers("BOLD", taxon_name)

                return [result_file_manager, :cant_classify]
            elsif classify_dir
                ## TODO:
                ## here i shoul call functions for user provided dirs that have not been
                ## downloaded by taxalogue
            elsif params[:download][:bold_dir]
                ## NEXT
                ## now i need to download the failed files
                ## the problem is that it will create a new folder...
                ## it should "just" add the downloads to the existing folder
                puts "There were no downloads available, therefore also no failed downloads. Consider starting again: bundle exec ruby taxalogue.rb download --all"
                exit
            else
                download_file_managers  = _download_files
            end

            did_use_marshal_file    = false
        else
            did_use_marshal_file    =  true
        end

        if params[:download][:bold_dir]
            download_file_managers = _download_failed_files
            _write_marshal_files(download_file_managers) 
        end

        _classify_downloads(download_file_managers)     unless download_only
        _write_marshal_files(download_file_managers)    unless did_use_marshal_file || classify_only || classify_dir
        # byebug
        return [result_file_manager, download_file_managers]
    end

    def _get_download_file_managers_from_already_downloaded_dir(already_downloaded_dir)
        return [] unless already_downloaded_dir
        
        begin
            download_file_managers = DownloadCheckHelper.get_object_from_marshal_file(already_downloaded_dir + '.download_file_managers.dump')
            
            unless download_only
                BoldDownloadCheckHelper.create_download_info_for_result_dir(download_file_managers: download_file_managers, result_file_manager: result_file_manager, source: self.class)
                DownloadCheckHelper.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir: already_downloaded_dir, result_file_manager: result_file_manager, source: self.class)
            end
            
            return download_file_managers
        rescue => e
            puts "Release directory could not be used."
            pp e
            sleep 2
            
            return []
        end
    end

    def _write_marshal_files(download_file_managers)
        MiscHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: download_file_managers, file_name: '.download_file_managers.dump')
        MiscHelper.write_marshal_file(dir: BOLD_DIR + @root_download_dir, data: taxon, file_name: '.taxon_object.dump')
    end

    def _create_download_info_for_result_dir(already_downloaded_dir)
        data_dl_info_public_name = already_downloaded_dir + 'download_info.txt'
        data_dl_info_hidden_name = already_downloaded_dir + '.download_info.txt'

        result_dl_info_public_name = result_file_manager.dir_path + 'download_info.txt'
        result_dl_info_hidden_name = result_file_manager.dir_path + '.download_info.txt'

        dl_info_public = File.open(data_dl_info_public_name).read
        dl_info_hidden = File.open(data_dl_info_hidden_name).read

        dl_info_public.gsub!(/^ result directory:.*$/, "data directory: #{already_downloaded_dir.to_s}")
        dl_info_hidden.gsub!(/^ result directory:.*$/, "data directory: #{already_downloaded_dir.to_s}")
        
        File.open(result_dl_info_public_name, 'w') { |f| f.write(dl_info_public) }
        File.open(result_dl_info_hidden_name, 'w') { |f| f.write(dl_info_hidden) }
    end

    def _download_response(downloader:, file_path:)
        begin 
            downloader.run
            return :empty_file if File.empty?(file_path)
            return :server_offline if _server_is_offline(file_path)
        rescue Net::ReadTimeout => e
            return :read_timeout
        rescue Net::OpenTimeout => e
            return :open_timeout
        rescue SocketError => e
            return :socket_error
        rescue StandardError => e
            return :other_error
        end

        return :success
    end

    def _download_failed_files
        tree_file_name                  = params[:download][:bold_dir] + ".bold_download_tree_info.txt"
        tree                            = DownloadInfoParser._parse(tree_file_name)
        failed_tree_nodes               = DownloadInfoParser.get_download_failures(tree_file_name)
        download_file_managers          = DownloadInfoParser.get_file_managers_from_download_info_tree(tree_file_name)
        failed_names                    = failed_tree_nodes.collect { |node| node.name }
        failed_download_file_managers   = download_file_managers.select { |dfm| failed_names.include?(dfm.config.name)  }
        still_failed_nodes              = []
        root_node                       = tree.root

        root_dfm = download_file_managers.detect { |dfm| dfm.config.name == tree.root.name }
        return :cant_find_root if root_dfm.nil?

        @root_download_dir = root_dfm.base_dir.basename

        GbifTaxonomy.possible_ranks.size.times do |i|
            break if i >= (GbifTaxonomy.possible_ranks.size - 1)
            break if failed_tree_nodes.empty?

            ## go through each failed tree node and try downloading it
            # failed_tree_nodes.each do |node|
            Parallel.map(failed_tree_nodes, in_threads: num_threads) do |node|
                file_manager = failed_download_file_managers.detect { |dfm| node.name == dfm.config.name }
                next if file_manager.nil?
    
                stats_file_path = file_manager.dir_path + "#{node.name}_stats.json"
                stats_downloader = HttpDownloader2.new(address: _bold_stats_api(node.name), destination: stats_file_path)
                no_stats_file = nil
    
                stats_file_path = file_manager.dir_path + "#{node.name}_stats.json"
                rank_status = _get_rank_status(node.name, stats_file_path)
                
                file_manager.status = 'loading'
                config = file_manager.config

                puts "downloading failed taxon: #{node.name}"
    
                downloader = config.downloader.new(config: config)
                download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
    
                node_record  = TaxonHelper.get_taxon_record(params, node.name, automatic: true)
                next if node_record.nil?

                node.content = [node_record]
                if download_response == :success
                    node.content[1] = @success
                    node.content[2] = download_response.to_s
                    file_manager.status = 'success'
                    sleep 1

                elsif download_response == :empty_file
                    node.content[1] = @failure
                    node.content[2] = download_response.to_s
                    file_manager.status = 'failure'
                    sleep 5

                elsif download_response == :read_timeout
                    node.content[1] = @failure
                    node.content[2] = download_response.to_s
                    file_manager.status = 'failure'
                    sleep 5

                elsif download_response == :open_timeout || download_response == :server_offline || download_response == :socket_error || download_response == :other_error 
                    node.content[1] = @failure
                    node.content[2] = download_response.to_s
                    file_manager.status = 'failure'
                end

                puts "downloading failed taxon: #{node.name} => #{file_manager.status}"
                if file_manager.status == 'failure' && node_record.taxon_rank != 'species'
                    puts "starting lower ranks soon"
                    still_failed_nodes.push(node)
                end
            end

            failed_tree_nodes = still_failed_nodes
            
            ## find lower ranks for failed nodes
            failed_tree_nodes.each do |failed_node|
                node_record                     = failed_node.content.first
                node_name                       = failed_node.name
                index_of_rank                   = GbifTaxonomy.possible_ranks.index(node_record.taxon_rank)
                index_of_lower_rank             = index_of_rank - 1
                taxon_rank_to_try               = GbifTaxonomy.possible_ranks[index_of_lower_rank]
                
                taxa_records_and_names_to_try = nil
                if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
                    taxa_records_and_names_to_try   = GbifTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
                elsif taxonomy_params[:ncbi]
                    taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try, params: params)
        
                else
                    taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try, params: params)
                end
    
                next if taxa_records_and_names_to_try.nil?
    
                added_names = []
                taxa_records_and_names_to_try.each do |record_and_name|
    
                    record  = record_and_name.first
                    name    = record_and_name.last
                    
                    next if TaxonHelper.is_extinct?(name)
                    next if added_names.include?(name) # prevent breaking if name occurs multiple times maybe due to wrong backbone
    
                    failed_node << Tree::TreeNode.new(name, [record, @pending, 'pending'])
                    added_names.push(name)
                end
            end
        end

        dl_path_public      = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden      = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public      = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden      = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        dl_tree_path_hidden = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_TREE_NAME}")
        dl_tree_path_public = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_TREE_NAME)
        
        _write_download_info_tree(paths: [dl_tree_path_hidden, dl_tree_path_public], root_node: root_node)
        
        failures    = DownloadInfoParser.get_download_failures(dl_tree_path_hidden)
        success     = failures.empty? ? true : false
        
        if download_only
            DownloadCheckHelper.write_download_info(paths: [dl_path_public, dl_path_hidden], success: success, download_file_managers: download_file_managers, result_file_manager: result_file_manager)
        else
            DownloadCheckHelper.write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers, result_file_manager: result_file_manager)
        end
        
        unless failures.empty?
            ## maybe directly try to download again?
        end

        return download_file_managers
    end

    def _download_files
        root_node               = Tree::TreeNode.new(taxon_name, [taxon, @pending, 'pending'])
        num_of_ranks            = GbifTaxonomy.possible_ranks.size
        reached_species_level   = false
        download_file_managers  = []
        rest_taxa               = Hash.new

        num_of_ranks.times do |i|
            _print_download_progress_report(root_node: root_node, rank_level: i)

            Parallel.map(root_node.entries, in_threads: num_threads) do |node|
                next unless node.content[1] == @pending

                config = _create_config(node: node)

                file_manager = config.file_manager
                file_manager.create_dir
                
                @root_download_dir = file_manager.base_dir.basename if node.is_root?

                stats_file_path = file_manager.dir_path + "#{node.name}_stats.json"
                stats_downloader = HttpDownloader2.new(address: _bold_stats_api(node.name), destination: stats_file_path)
                no_stats_file = nil

                stats_file_path = file_manager.dir_path + "#{node.name}_stats.json"
                rank_status = _get_rank_status(node.name, stats_file_path, reached_species_level)

                node.content[1] = @loading
                node.content[2] = 'loading'
                file_manager.status = 'loading'

                ## skip since download never succeeds due to too many records or other reasons
                if rank_status == :no_records || rank_status == :failing_taxon # || rank_status == :too_many_records 
                    node.content[1] = @failure
                    node.content[2] = rank_status.to_s
                    file_manager.status = 'failure'
                    download_file_managers.push(file_manager)
                    _print_download_progress_report(root_node: root_node, rank_level: i)
                    next
                end


                downloader = config.downloader.new(config: config)
                _print_download_progress_report(root_node: root_node, rank_level: i)
                download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
        
                if download_response == :success
                    node.content[1] = @success
                    node.content[2] = download_response.to_s
                    file_manager.status = 'success'
                    sleep 1

                elsif download_response == :empty_file
                    node.content[1] = @failure
                    node.content[2] = download_response.to_s
                    file_manager.status = 'failure'
                    sleep 5

                elsif download_response == :read_timeout
                    if reached_species_level
                        3.times do
                            sleep 5
                            download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
              
                            break if download_response == :success
                        end
  
                        if download_response == :success
                            node.content[1] = @success
                            node.content[2] = download_response.to_s
                            file_manager.status = 'success'
                        else
                            node.content[1] = @failure
                            node.content[2] = download_response.to_s
                            file_manager.status = 'failure'
                        end
                    else
                        node.content[1] = @failure
                        node.content[2] = download_response.to_s
                        file_manager.status = 'failure'
                    end

                elsif download_response == :open_timeout || download_response == :server_offline || download_response == :socket_error || download_response == :other_error 
                    3.times do
                        sleep 120
                        download_response = _download_response(downloader: downloader, file_path: file_manager.file_path)
                        
                        break if download_response == :success
                    end

                    if download_response == :success
                        node.content[1] = @success
                        node.content[2] = download_response.to_s
                        file_manager.status = 'success'
                    else
                        node.content[1] = @failure
                        node.content[2] = download_response.to_s
                        file_manager.status = 'failure'
                    end
                end

                download_file_managers.push(file_manager)

                _print_download_progress_report(root_node: root_node, rank_level: i)
            end

            break if reached_species_level
            # break if i == 2

            failed_nodes = root_node.find_all { |node| node.content[1] == @failure && node.is_leaf? }
            failed_nodes.each do |failed_node|
                node_record                     = failed_node.content.first
                node_name                       = failed_node.name
                index_of_rank                   = GbifTaxonomy.possible_ranks.index(node_record.taxon_rank)
                index_of_lower_rank             = index_of_rank - 1
                reached_species_level           = true if index_of_lower_rank == 0
                taxon_rank_to_try               = GbifTaxonomy.possible_ranks[index_of_lower_rank]
                
                taxa_records_and_names_to_try = nil
                if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
                    taxa_records_and_names_to_try   = GbifTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try)
        
                elsif taxonomy_params[:ncbi]
                    taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try, params: params)
        
                else
                    taxa_records_and_names_to_try   = NcbiTaxonomy.taxa_names_for_rank(taxon: node_record, rank: taxon_rank_to_try, params: params)
                
                end

                next if taxa_records_and_names_to_try.nil?

                added_names = []
                taxa_records_and_names_to_try.each do |record_and_name|

                    record  = record_and_name.first
                    name    = record_and_name.last
                    
                    next if TaxonHelper.is_extinct?(name)
                    next if added_names.include?(name) # prevent breaking if name occurs multiple times maybe due to wrong backbone

                    failed_node << Tree::TreeNode.new(name, [record, @pending, 'pending'])
                    added_names.push(name)
                end
            end
        end

        # _write_result_files(root_node: root_node, download_file_managers: download_file_managers)

        dl_path_public = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_NAME)
        dl_path_hidden = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_NAME}")
        rs_path_public = Pathname.new(result_file_manager.dir_path + DOWNLOAD_INFO_NAME)
        rs_path_hidden = Pathname.new(result_file_manager.dir_path + ".#{DOWNLOAD_INFO_NAME}")
        
        dl_tree_path_hidden = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + ".#{DOWNLOAD_INFO_TREE_NAME}")
        dl_tree_path_public = Pathname.new(BoldConfig::DOWNLOAD_DIR + @root_download_dir + DOWNLOAD_INFO_TREE_NAME)
        
        _write_download_info_tree(paths: [dl_tree_path_hidden, dl_tree_path_public], root_node: root_node)
        
        failures = DownloadInfoParser.get_download_failures(dl_tree_path_hidden)
        success = failures.empty? ? true : false
        
        if download_only
            DownloadCheckHelper.write_download_info(paths: [dl_path_public, dl_path_hidden], success: success, download_file_managers: download_file_managers, result_file_manager: result_file_manager)
        else
            DownloadCheckHelper.write_download_info(paths: [dl_path_public, dl_path_hidden, rs_path_public, rs_path_hidden], success: success, download_file_managers: download_file_managers, result_file_manager: result_file_manager)
        end
        
        unless failures.empty?
            ## maybe directly try to download again?
        end

        return download_file_managers
    end

    def _write_download_info_tree(paths:, root_node:)

        paths.each do |path|
            file = File.open(path, 'w')

            root_node_copy = root_node.detached_subtree_copy
            root_node_copy.each do |node|
                node.content = node.content.is_a?(Array) ? node.content.last : node.content 
            end

            real_failed_nodes = root_node.find_all { |node| node.is_leaf? && _real_failure(node.content[2]) }
            success = real_failed_nodes.empty? ? 'true' : 'false'
            file.puts 'data:'
            file.puts "success: #{success}"
            file.puts
            file.puts 'tree:'

            basename = path.basename.to_s
            if basename.starts_with?('.')
                hash = root_node_copy.to_h
                json_hash = hash.to_json

                file.puts(json_hash)
            else
                root_node_copy.print_tree(level = root_node.node_depth, max_depth = nil, block = lambda { |node, prefix| file.puts "#{prefix} #{node.name}".ljust(30) + " #{node.content}" })
            end

            file.rewind
        end
    end

    def _real_failure(node_content)
        node_content == 'server_offline' || node_content == 'read_timeout' || node_content == 'open_timeout' || node_content == 'socket_error' || node_content == 'other_error' 
    end

    ## UNUSED
    def _needs_rest_download(node_content)
        node_content == 'server_offline' || node_content == 'read_timeout' || node_content == 'open_timeout' || node_content == 'socket_error' || node_content == 'other_error' || node_content == 'too_many_records' || node_content == 'failing_taxon'
    end

    ## UNUSED
    def _rest_query(failed_taxon, taxa_to_exclude)

        base = 'http://www.boldsystems.org/index.php/API_Public/combined?'
        

        max_query_size = 8190 ## apache default
        max_query_size -= 120 ## minus base + additional query
        taxa = []
        taxa_to_exclude.each_with_index do |taxon, i|
            taxon_name = taxon.last
            excluded_taxon_name = taxon_name.split.unshift('-').join('')
            taxa.push(excluded_taxon_name)
            char_count = taxa.join.size + (i+1) ## add # | delimiter
            if char_count >= max_query_size
                taxa.pop
                break
            end
        end

        excluded_taxa_string = taxa.join('|')
        query = excluded_taxa_string.dup.prepend("taxon=")
        query = query.concat("|#{failed_taxon}")
        query = query.concat('&format=tsv')
        
        if query.size >= max_query_size
        ## TODO:
        end
        query = base.dup.concat(query)

        return query
    end

    def _print_download_progress_report(root_node:, rank_level:)
        root_copy = root_node.detached_subtree_copy

        system("clear") || system("cls")
        puts

        nodes_currently_loading = root_copy.find_all { |node| node.content[1] == @loading && node.is_leaf? }
        return if nodes_currently_loading.nil?
        
        if rank_level <= 1
            root_copy.print_tree(level = root_copy.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content[1]}" })
            _print_legend
            return
        end

        already_printed_parents = []
        loading_parent_nodes    = []
        nodes_currently_loading.each { |node| loading_parent_nodes.push(node.parentage); loading_parent_nodes.flatten! }
        
        root_copy.print_tree(level = root_copy.node_depth, max_depth = 1, block = lambda { |node, prefix| puts loading_parent_nodes.include?(node) ? "#{prefix} #{Pastel.new.white.on_blue(node.name)}".ljust(30 + @loading_color_char_num) + " #{node.content[1]}" : "#{prefix} #{node.name}".ljust(30) + " #{node.content[1]}" })
        
        puts
        puts "currently loading:"
        nodes_currently_loading.each do |loading_node|
        not_loading_nodes = loading_node.parent.find_all { |node| node.content[1] != @loading && node.is_leaf? }
            not_loading_nodes.each do |not_loading_node|
                loading_node.parent.remove!(not_loading_node)
            end

            if already_printed_parents.include?(loading_node.parent.name)
                next
            else
                loading_node.parent.print_tree(level = loading_node.parent.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content[1]}" })
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
            config        = BoldConfig.new(name: node.name, markers: markers, is_root: true)
        end
    end

    def _get_parentage_as_dir_structure(node)
        if node.parentage
            parent_names  = []
            node.parentage.each do |parent_node|
                parent_node.is_root? ? parent_names.push((@root_download_dir + parent_node.name)) : parent_names.push(Pathname.new(parent_node.name))
            end
            # parent_dir = parent_names.reverse.join('/')
            begin
                parent_dir = parent_names.reverse.inject(:+)
            rescue TypeError
            end
            
            return parent_dir
        end
    end

    ## TODO: same for NcbiTaxonomy
    ## UNUSED
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

    def _write_result_files(root_node:, download_file_managers:)
        root_dir              = download_file_managers.select { |m| m.name == root_node.name }.first
        # merged_download_file  = File.open(root_dir.dir_path + "#{root_dir.name}_merged.tsv", 'w') 
        download_info_file    = File.open(root_dir.dir_path + "#{root_dir.name}_download_info.tsv", 'w') 
        # download_successes    = download_file_managers.select { |m| m.status == 'success' }

        # OutputFormat::MergedBoldDownload.write_to_file(file: merged_download_file, data: download_successes, header_length: HEADER_LENGTH, include_header: true)
        OutputFormat::DownloadInfo.write_to_file(file: download_info_file, download_file_managers: download_file_managers)
    end

    def _classify_downloads(download_file_managers)
        download_file_managers.each do |download_file_manager|
            next unless download_file_manager.status == 'success'
            next unless File.file?(download_file_manager.file_path)

            bold_classifier   = BoldClassifier.new(params: params, file_name: download_file_manager.file_path, file_manager: result_file_manager)
            bold_classifier.run ## result_file_manager creates new files and will push those into internal array
        end
    end

    ## UNUSED
    def _merge_results
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Tsv)
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Fasta)
        FileMerger.run(file_manager: result_file_manager, file_type: OutputFormat::Comparison)
    end

    def _server_is_offline(file_path)
        File.open(file_path, &:gets) =~ /<!DOCTYPE html>/
    end

    def _bold_stats_api(name)
        "http://www.boldsystems.org/index.php/API_Public/stats?taxon=#{name}&format=json"
    end

    def _get_rank_status(name, file_path, reached_species_level = nil)
        failing_taxa = ['Arthropoda', 'Insecta', 'Arachnida', 'Collembola', 'Malacostraca']
        stats_downloader = HttpDownloader2.new(address: _bold_stats_api(name), destination: file_path)
        no_stats_file = nil

        if failing_taxa.include?(name)
            no_stats_file = true
        else
            begin
                stats_downloader.run
            rescue StandardError
                no_stats_file = true
            end
        end

        rank_status = nil
        if no_stats_file
            if reached_species_level
                rank_status = :species_rank
            else
                rank_status = :failing_taxon
            end
        else
            if reached_species_level
                rank_status = :species_rank
            else
                begin
                    stats = MiscHelper.json_file_to_hash(file_path)
                rescue StandardError
                    return :malformed_stats_file
                end
                num_total_records = stats["total_records"]
                
                if !num_total_records.nil? && num_total_records == 0
                    rank_status = :no_records
                # elsif !num_total_records.nil? && num_total_records <= 90_000
                #     rank_status = :suitable_records_num
                # else
                #     rank_status = :too_many_records
                end
            end
        end

        return rank_status
    end
end
