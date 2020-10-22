# frozen_string_literal: true

class OutputFormat::DownloadInfo
      
      def self.write_to_file(file:, fmanagers:)
            fmanagers.each_with_index do |file_manager, i|
                  file.puts "name\tstatus\tversioning\tdir_path\tfile_path" if i == 0
                  
                  file.print  file_manager.name, "\t"
                  file.print  file_manager.status, "\t"
                  file.print  file_manager.versioning, "\t"
                  file.print  file_manager.dir_path, "\t"
                  file.puts   file_manager.file_path
            end
      end
  end