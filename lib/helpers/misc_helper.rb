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
        contaminants_dir_path = Pathname.new('fm_data/NCBIGENBANK/inv_contaminants/')
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
end