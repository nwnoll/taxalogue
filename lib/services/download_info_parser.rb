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
            if file.lineno == 1
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

end