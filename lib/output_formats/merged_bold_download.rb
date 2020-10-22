# frozen_string_literal: true

class OutputFormat::MergedBoldDownload
      
    def self.write_to_file(file:, data:)
        data.each_with_index do |file_manager, i|
            sub_file = File.open(file_manager.file_path, 'r')
            sub_file.each_line do |line|
                next if sub_file.lineno == 1 && i != 0
                file.puts line
            end
        end
    end
end