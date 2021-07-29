# frozen_string_literal: true

class DownloadCheckHelper

    RJUST_LEVEL_ONE = " " * 6
    RJUST_LEVEL_TWO = " " * 10

    def self.get_taxon_record_from_marshal_dump(dir)
        file_path = dir + '.taxon_object.dump'
        if File.file?(file_path)
            begin
                taxon_object = Marshal.load(File.open(file_path, 'rb').read)
                return taxon_object
            rescue StandardError
                return nil
            end
        else
            return nil
        end
    end

    def self.write_marshal_file(dir:, file_name:, data:)
        marshal_dump_file_name = dir + file_name
        data_dump = Marshal.dump(data)
        
        File.open(marshal_dump_file_name, 'wb') { |f| f.write(data_dump) }
    end

    def self.get_object_from_marshal_file(file_name)
        Marshal.load(File.open(file_name, 'rb').read)
    end

    def self.create_download_info_for_result_dir(download_file_managers:, result_file_manager:, source:, release_info_struct: nil)
        download_info_str = source::DOWNLOAD_INFO_NAME

        result_dl_info_public_name = result_file_manager.dir_path + download_info_str
        result_dl_info_hidden_name = result_file_manager.dir_path + ".#{download_info_str}"

        success = download_file_managers.all? { |fm| fm.status == 'success'}

        paths = [result_dl_info_public_name, result_dl_info_hidden_name]
        paths.each do |path|
            file = File.open(path, 'w')
            download_file_managers.each_with_index do |download_file_manager, i|
                if release_info_struct
                    file.puts 'data:' if i == 0
                    file.puts "#{release_info_struct.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0

                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO)
                else
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0 && source != GbolJob

                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO) if source != GbolJob
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_ONE) if source == GbolJob
                end
            end
        end
    end


    def self.update_already_downloaded_dir_on_new_result_dir(already_downloaded_dir:, result_file_manager:, source:)
        download_info_str = source::DOWNLOAD_INFO_NAME

        pub_name = already_downloaded_dir + download_info_str
        hid_name = already_downloaded_dir + ".#{download_info_str}"

        paths = [pub_name, hid_name]
        paths.each do |path|
            next unless File.file?(path)

            file = File.open(path, 'a')
            file.puts "#{result_file_manager.dir_path.to_s}".prepend(RJUST_LEVEL_ONE)
        end
    end

    def self.write_download_info(paths:, success:, download_file_managers:, result_file_manager:)
        paths.each do |path|
            file = File.open(path, 'w')

            download_file_managers.each_with_index do |download_file_manager, i|
                if path.descend.first.to_s == 'results'
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0
                    
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO)
                else
                    file.puts 'data:' if i == 0
                    file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".prepend(RJUST_LEVEL_ONE) if i == 0
                    
                    sub_directory_success = download_file_manager.status == 'success' ?  true : false
                    file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".prepend(RJUST_LEVEL_TWO)

                    file.puts 'results:' if i == (download_file_managers.size - 1)
                    file.puts "#{result_file_manager.dir_path.to_s}".prepend(RJUST_LEVEL_ONE) if i == (download_file_managers.size - 1)
                end
            end
            file.rewind
        end
    end

    def self.is_nil_or_empty?(data)
        data.nil? || data.empty?
    end
end