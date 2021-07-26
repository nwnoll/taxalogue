# frozen_string_literal: true

class MiscHelper
    def self.json_file_to_hash(file_name)
        file = File.read(file_name)
        hash = JSON.parse(file)
    
        return hash
    end

    def self.constantize(s)
        Object.const_get(s)
    end

    def self.generate_index_by_column_name(file:, separator:)
        column_names          = file.first.chomp.split(separator)
        num_columns           = column_names.size
        index_by_column_name  = Hash.new
        (0...num_columns).each do |index|
            index_by_column_name[column_names[index]] = index
        end
    
        return index_by_column_name
    end

    def self.extract_zip(name:, destination:, files_to_extract:, retain_hierarchy: false)
        # does not extract csv file..
        FileUtils.mkdir_p(destination)
        Zip::File.open(name) do |zip_file|
            zip_file.each do |f|
                
                pathname  = Pathname.new(f.name)
                basename  = pathname.basename
                dirname   = pathname.dirname
                
                next unless files_to_extract.include?(f.name)
        
                if retain_hierarchy
                    dir_path = File.join(destination, dirname)
                    FileUtils.mkpath(dir_path)
            
                    fpath = File.join(destination, pathname)
                    zip_file.extract(f, fpath) unless File.exist?(fpath)
                else
                    fpath = File.join(destination, basename)
                    zip_file.extract(f, fpath) unless File.exist?(fpath)
                end
            end
        end
    end

    def self.normalize(string)
        string.tr(
        "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
        "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
        )
    end

    def self.create_marker_objects(query_marker_names:)
        return [] if query_marker_names.nil?
        
        marker_names = query_marker_names.split(',')
        marker_objects = []
        marker_names.each do |marker_name|
            marker = Marker.new(query_marker_name: marker_name)
            marker_objects.push(marker)
        end
        
        return marker_objects
    end

    def self.get_inv_contaminants(file_manager, marker_objects)
        # contaminants_dir_path = file_manager.dir_path + 'contaminants/'
        contaminants_dir_path = Pathname.new('downloads/NCBIGENBANK/inv_contaminants/')
        FileUtils.mkdir_p(contaminants_dir_path)
        
        wolbachia_contaminants_file_path = contaminants_dir_path + 'Wolbachia.gb'
        
        ncbi_api = NcbiApi.new(markers: marker_objects, taxon_name: 'Wolbachia', max_seq: 100, file_name: wolbachia_contaminants_file_path)
        ncbi_api.efetch
        
        human_contaminants_file_path = contaminants_dir_path + 'Homo_sapiens.gb'
        
        ncbi_api = NcbiApi.new(markers: marker_objects, taxon_name: 'Homo sapiens', max_seq: 10, file_name: human_contaminants_file_path)
        ncbi_api.efetch
    
        result_contaminants_dir_path = file_manager.dir_path + 'contaminants/'
        FileUtils.mkdir_p(result_contaminants_dir_path)
        
        wolbachia_result_contaminants_file_path = result_contaminants_dir_path + 'Wolbachia_output.out'
        ncbi_genbank_extractor = NcbiGenbankExtractor.new(file_name: wolbachia_contaminants_file_path, taxon_name: 'Wolbachia', markers: marker_objects, result_file_name: wolbachia_result_contaminants_file_path)
        ncbi_genbank_extractor.run
    
        human_result_contaminants_file_path = result_contaminants_dir_path + 'Homo_sapiens_output.out'
        ncbi_genbank_extractor = NcbiGenbankExtractor.new(file_name: human_contaminants_file_path, taxon_name: 'Homo sapiens', markers: marker_objects, result_file_name: human_result_contaminants_file_path)
        ncbi_genbank_extractor.run
    end

    def merge_files_in_dir(dir_name)
        ## TODO: refactor and maybe implement into FileMerger?
    
        dir = Pathname.new(dir_name)
    
        tsv_files = dir.glob("*_output.tsv")
        fas_files = dir.glob("*_output.fas")
        cmp_files = dir.glob("*_comparison.tsv")
    
    
        merged_tsv_file_name  = dir + "merged_output.tsv"
        merged_fas_file_name  = dir + "merged_output.fas"
        merged_cmp_file_name  = dir + "merged_comparison.tsv"
    
        merged_tsv_file = File.open(merged_tsv_file_name, 'w')
        merged_fas_file = File.open(merged_fas_file_name, 'w')
        merged_cmp_file = File.open(merged_cmp_file_name, 'w')
        
        tsv_files.each_with_index do |file, i|
                next unless File.file?(file)
                file_in = File.open(file, 'r')
                file_in.each_line do |line|
                    next if file_in.lineno == 1 && i != 0 ## header only once
                    merged_tsv_file.write line
                end
                file_in.close
        end
        merged_tsv_file.close
    
        fas_files.each_with_index do |file, i|
            next unless File.file?(file)
            file_in = File.open(file, 'r')
            file_in.each_line do |line|
                merged_fas_file.write line
            end
            file_in.close
        end
        merged_fas_file.close
    
        cmp_files.each_with_index do |file, i|
            next unless File.file?(file)
            file_in = File.open(file, 'r')
            file_in.each_line do |line|
                next if file_in.lineno == 1 && i != 0 ## header only once
                merged_cmp_file.write line
            end
            file_in.close
        end
        merged_cmp_file.close

        return nil
    end
end