# frozen_string_literal: true

class DownloadInfoParser

    def self.download_was_successful?(file_path)
        return false unless File.file?(file_path)
        
        file = File.open(file_path, 'r')

        line = File.readlines(file)[1]
        success = line =~ /success: true/ ? true : false

        file.rewind

        return success
    end

    def self.get_download_failures(file_path)
        success = DownloadInfoParser.download_was_successful?(file_path)
        return [] if success
        
        tree = DownloadInfoParser._parse(file_path)

        failures = tree.find_all { |node| node.is_leaf? && _real_failure(node.content) }

        # tree.print_tree(level = tree.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content}" })

        return failures
    end

    def self._parse(file_path)

        file = File.open(file_path, 'r')
        hash = nil
        file.each do |line|
            if file.lineno == 5
                hash = JSON.parse(line)
            end
        end

        file.rewind

        tree = Tree::TreeNode.from_hash(hash)

        tree.each do |node|
            name_content = node.name
            name_content = name_content[1..-2]
            name_content.gsub!('"', '')
            name, content = name_content.split(', ')

            node.rename(name)
            node.content = content
        end

        # tree.print_tree(level = tree.node_depth, max_depth = nil, block = lambda { |node, prefix| puts "#{prefix} #{node.name}".ljust(30) + " #{node.content}" })


        return tree
    end

    def self._real_failure(node_content)
        node_content == 'server_offline' || node_content == 'read_timeout' || node_content == 'open_timeout' || node_content == 'socket_error' || node_content == 'other_error' 
    end

    def self.classify_with_already_downloaded_dirs(file_managers, params, result_file_manager)
        file_managers.each do |file_manager|
            # puts file_manager.file_path
            # puts file_manager.status
            next unless file_manager.status == 'success'
            # puts file_manager.file_path if !File.file?(file_manager.file_path)
            next unless File.file?(file_manager.file_path)
            # puts file_manager.file_path
            # puts
            bold_classifier = BoldClassifier.new(fast_run: false, file_name: file_manager.file_path, query_taxon_object: params[:taxon_object], file_manager: result_file_manager, filter_params: params[:filter], markers: params[:marker_objects], taxonomy_params: params[:taxonomy], region_params: params[:region])
            bold_classifier
            bold_classifier.run ## result_file_manager creates new files and will push those into internal array
        end
    end

    def self.get_file_managers_from_download_info_tree(tree_file_name)
        tree_file_path = Pathname.new(tree_file_name)
        tree = DownloadInfoParser._parse(tree_file_path)
        root_download_dir = Pathname.new(tree_file_path.dirname.basename)
        file_managers = []
        tree.each do |node|
            config = DownloadInfoParser._create_config(node, root_download_dir)
            if node.is_root?
                file_manager = config.file_manager(root_download_dir)
                file_manager.status = node.content
            else
                file_manager = config.file_manager
                file_manager.status = node.content
            end


            if node.is_leaf? && node.content == 'read_timeout'
                file_manager.status = 'success'
                ## TODO: remove lateron, this is atm the case since I downloaded the failed ones
                ## manually
                
                
                # pp file_manager
                # puts node.name
                # puts node.is_leaf?
                # puts file_manager.file_path
                # pp node.content
                # sleep 2
            end

            file_managers.push(file_manager)
        end
        
        return file_managers
    end



    def self._create_config(node, root_download_dir)
        if node.parentage
            parent_dir    = _get_parentage_as_dir_structure(node, root_download_dir)
            config        = BoldConfig.new(name: node.name, markers: nil, parent_dir: parent_dir)
        else
            config        = BoldConfig.new(name: node.name, markers: nil, is_root: true)
        end
    end

    def self._get_parentage_as_dir_structure(node, root_download_dir)
        if node.parentage
            parent_names  = []
            node.parentage.each do |parent_node|
                parent_node.is_root? ? parent_names.push((root_download_dir + parent_node.name)) : parent_names.push(Pathname.new(parent_node.name))
            end
            # parent_dir = parent_names.reverse.join('/')
            begin
                parent_dir = parent_names.reverse.inject(:+)
            rescue TypeError
            end
            
            return parent_dir
        end
    end

end