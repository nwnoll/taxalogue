# frozen_string_literal: true

class OutputFormat::DownloadInfo
      
    def self.write_to_file(file:, download_file_managers:)
        download_file_managers.each_with_index do |file_manager, i|

            file.puts "name\tstatus\tversioning\tdir_path\tfile_path" if i == 0

            if file_manager.multiple_files_per_dir
                downloaded_files = file_manager.files_with_name_of(dir: file_manager.dir_path)
                downloaded_files.each do |downloaded_file|
                    file.print  file_manager.name, "\t"
                    file.print  file_manager.status, "\t"
                    file.print  file_manager.versioning, "\t"
                    file.print  file_manager.dir_path, "\t"
                    file.puts   downloaded_file
                end
            else
                file.print  file_manager.name, "\t"
                file.print  file_manager.status, "\t"
                file.print  file_manager.versioning, "\t"
                file.print  file_manager.dir_path, "\t"
                file.puts   file_manager.file_path
            end
        end
    end
end