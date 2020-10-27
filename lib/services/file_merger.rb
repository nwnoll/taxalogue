# frozen_string_literal: true

class FileMerger
      def self.run(file_manager:, file_type:)

            merged_file_name  = _to_merged_name(file_type)
            return nil if merged_file_name.nil?

            merged_file_path  = file_manager.dir_path + merged_file_name
            return nil if merged_file_path.nil?

            merged_file_out   = file_manager.create_file(merged_file_name, _to_merged_type(file_type))
            
            files             = file_manager.created_files.select { |f| f.type == file_type }
            files.each_with_index do |file, i|
                  next unless File.file?(file.path)

                  file_in = File.open(file.path, 'r')
                  next if file_in.lineno == 1 && i != 0 && file.type != OutputFormat::Fasta # print tsv header only once

                  fcreate_fileile_in.each_line { |line| merged_file_out.write line }
                  file_in.close
            end

            merged_file_out.close
      end

      private 
      def self._to_merged_name(type)
            if type == OutputFormat::Tsv
                  return 'merged_output.tsv'
            elsif type == OutputFormat::Fasta
                  return 'merged_output.fas'
            elsif type == OutputFormat::Comparison
                  return 'merged_comparison.tsv'
            else
                  return nil
            end
      end

      def self._to_merged_type(type)
            if type == OutputFormat::Tsv
                  return OutputFormat::MergedTsv
            elsif type == OutputFormat::Fasta
                  return OutputFormat::MergedFasta
            elsif type == OutputFormat::Comparison
                  return OutputFormat::MergedComparison
            else
                  return nil
            end
      end
end