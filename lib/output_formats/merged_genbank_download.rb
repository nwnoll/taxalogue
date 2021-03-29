# frozen_string_literal: true

class OutputFormat::MergedGenbankDownload
      
      def self.write_to_file(file_name:, data:, header_length:, include_header:)
            gz = Zlib::GzipWriter.open(file_name)
            data.each do |file_manager|
                  downloaded_files = file_manager.files_with_name_of(dir: file_manager.dir_path)

                  downloaded_files.each do |downloaded_file|

                        Zlib::GzipReader.open(downloaded_file) do |gz_file|
                              
                              gz_file.each_line do |line|
                                    next if gz_file.lineno <= header_length && !include_header
                                    gz.write line
                              end
                        end
                  end
            end

            gz.close

      end
end