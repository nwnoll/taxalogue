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
            
            file_in.each_line do |line|
                next if file_in.lineno == 1 && i != 0 && (file.type == OutputFormat::Tsv || file.type == OutputFormat::Comparison) # print tsv header only once
                
                merged_file_out.write line
            end
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
        elsif type == OutputFormat::Qiime2TaxonomyFasta
            return 'merged_qiime2_taxonomy.fas'
        elsif type == OutputFormat::Comparison
            return 'merged_comparison.tsv'
        elsif type == OutputFormat::Qiime2Taxonomy
            return 'merged_qiime2_taxonomy.txt'
        elsif type == OutputFormat::Kraken2Fasta
            return 'merged_kraken2.fas'
        elsif type == OutputFormat::Dada2TaxonomyFasta
            return 'merged_dada2_taxonomy.fas'
        elsif type == OutputFormat::Dada2SpeciesFasta
            return 'merged_dada2_species.fas'
        elsif type == OutputFormat::SintaxFasta
            return 'merged_sintax.fas'
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
        elsif type == OutputFormat::Qiime2Taxonomy
            return OutputFormat::MergedQiime2Taxonomy
        elsif type == OutputFormat::Qiime2TaxonomyFasta
            return OutputFormat::MergedQiime2TaxonomyFasta
        elsif type == OutputFormat::Kraken2Fasta
            return OutputFormat::MergedKraken2Fasta
        elsif type == OutputFormat::Dada2TaxonomyFasta
            return OutputFormat::MergedDada2TaxonomyFasta
        elsif type == OutputFormat::Dada2SpeciesFasta
            return OutputFormat::MergedDada2SpeciesFasta
        elsif type == OutputFormat::SintaxFasta
            return OutputFormat::MergedSintaxFasta
        else
            return nil
        end
    end
end