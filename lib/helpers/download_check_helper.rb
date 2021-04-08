# frozen_string_literal: true

class DownloadCheckHelper
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

    def self.create_download_info_for_result_dir(already_downloaded_dir:, result_file_manager:, source:)
        download_info_str = source::DOWNLOAD_INFO_NAME
    
        data_dl_info_public_name = already_downloaded_dir + download_info_str
        data_dl_info_hidden_name = already_downloaded_dir + ".#{download_info_str}"
    
        result_dl_info_public_name = result_file_manager.dir_path + download_info_str
        result_dl_info_hidden_name = result_file_manager.dir_path + ".#{download_info_str}"
    
        dl_info_public = File.open(data_dl_info_public_name).read
        dl_info_hidden = File.open(data_dl_info_hidden_name).read
    
        dl_info_public.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
        dl_info_hidden.gsub!(/^corresponding result directory:.*$/, "corresponding data directory: #{already_downloaded_dir.to_s}")
        
        File.open(result_dl_info_public_name, 'w') { |f| f.write(dl_info_public) }
        File.open(result_dl_info_hidden_name, 'w') { |f| f.write(dl_info_hidden) }
    end

    def self.is_nil_or_empty?(data)
        data.nil? || data.empty?
    end
end