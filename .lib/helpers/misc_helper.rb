# frozen_string_literal: true

class MiscHelper
    PASTEL = Pastel.new

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
        _download_inv_contaminants(ncbi_api)
        
        human_contaminants_file_path = contaminants_dir_path + 'Homo_sapiens.gb'
        ncbi_api = NcbiApi.new(markers: marker_objects, taxon_name: 'Homo sapiens', max_seq: 10, file_name: human_contaminants_file_path)
        _download_inv_contaminants(ncbi_api)
        puts
    
        result_contaminants_dir_path = file_manager.dir_path + 'contaminants/'
        FileUtils.mkdir_p(result_contaminants_dir_path)
        
        wolbachia_result_contaminants_file_path = result_contaminants_dir_path + 'Wolbachia_output.out'
        ncbi_genbank_extractor = NcbiGenbankExtractor.new(file_name: wolbachia_contaminants_file_path, taxon_name: 'Wolbachia', markers: marker_objects, result_file_name: wolbachia_result_contaminants_file_path)
        ncbi_genbank_extractor.run
    
        human_result_contaminants_file_path = result_contaminants_dir_path + 'Homo_sapiens_output.out'
        ncbi_genbank_extractor = NcbiGenbankExtractor.new(file_name: human_contaminants_file_path, taxon_name: 'Homo sapiens', markers: marker_objects, result_file_name: human_result_contaminants_file_path)
        ncbi_genbank_extractor.run
    end

    def self._download_inv_contaminants(ncbi_api)
        3.times do |i| 
            begin
                puts "downloading possible invertebrate contaminants: #{ncbi_api.taxon_name}"
                ncbi_api.efetch

                return nil
            rescue => e
                if i == 2
                    puts "download failed"
                    puts "please download #{ncbi_api.taxon_name} sequences manually"
                    puts

                    return nil
                end 

                puts "download failure"
                puts "restarting..."
                puts
                sleep 10
            end
        end
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

    def self.print_params(params, file=nil)
        file ? (file.puts "You used the following parameters:") : (puts "You used the following parameters:")
        params.each do |key, value|
            next if key.to_s.match?("_object")
            # next if value.empty? || value.nil?

            file ? (file.puts "\t#{key}: #{value}") : (puts "\t#{key}: #{value}")
        end

        file ? (file.puts) : (puts)
    end

    def self.multiple_actions?(params)
        has_create_action   = params[:create].any?      ? 1 : 0
        has_download_action = params[:download].any?    ? 1 : 0
        has_classify_action = params[:classify].any?    ? 1 : 0
        has_merge_action    = params[:merge].any?       ? 1 : 0
        has_setup_action    = params[:setup].any?       ? 1 : 0
        has_update_action   = params[:update].any?      ? 1 : 0

        if (has_create_action + has_download_action + has_classify_action + has_merge_action + has_setup_action + has_update_action) > 1
            return true
        else
            return false
        end
    end

    def self.message_for_missing_download_file_managers(db_source, taxon)
        puts "Cannot classify #{db_source} downloads, since no downloads are available for #{taxon}."
        puts "Please use download command before you classify."
        puts "Or do it all at once with the create command."
        puts
    end

    def self.message_for_malformed_downloads(db_source, taxon)
        puts "Cannot classify #{db_source} downloads, since the downloaded files for #{taxon} are malformed."
        puts "Please use download again."
        puts "Or do it all at once with the create command."
        puts
    end

    def self.OUT_header(str)
        puts PASTEL.white.on_blue(str)
    end

    def self.OUT_question(str)
        puts PASTEL.black.on_yellow(str)
    end

    def self.OUT_error(str)
        puts PASTEL.white.on_red(str)
    end

    def self.OUT_success(str)
        puts PASTEL.white.on_green(str)
    end

    def self.run_file_merger(file_manager:, params:)
        return nil if params[:derep].any? {|opt| opt.last == true } && !params[:merge].any? { |opt| opt.last == true}
        
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Tsv)                    if params[:output][:table]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Fasta)                  if params[:output][:fasta]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Comparison)             if params[:output][:comparison]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Qiime2Taxonomy)         if params[:output][:qiime2]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Qiime2TaxonomyFasta)    if params[:output][:qiime2]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Kraken2Fasta)           if params[:output][:kraken2]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Dada2TaxonomyFasta)     if params[:output][:dada2_taxonomy]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Dada2SpeciesFasta)      if params[:output][:dada2_species]
    end

    def self.create_output_files(file_manager:, query_taxon_name:, file_name:, params:, source_db:)
        
        file_of = Hash.new
        if params[:output][:table]
            tsv                         = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_output.tsv", OutputFormat::Tsv)
            file_of[OutputFormat::Tsv]  = tsv
        end

        if params[:output][:fasta]
            fasta                           = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_output.fas", OutputFormat::Fasta)
            file_of[OutputFormat::Fasta]    = fasta
        end

        if params[:output][:qiime2]
            qiime2_taxonomy                         = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_qiime2_taxonomy.txt", OutputFormat::Qiime2Taxonomy)
            file_of[OutputFormat::Qiime2Taxonomy]   = qiime2_taxonomy
        end
        
        if params[:output][:qiime2] 
            qiime2_fasta                                = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_qiime2_taxonomy.fas", OutputFormat::Qiime2TaxonomyFasta)
            file_of[OutputFormat::Qiime2TaxonomyFasta]  = qiime2_fasta
        end

        if params[:output][:kraken2]
            kraken2_fasta                       = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_kraken2.fas", OutputFormat::Kraken2Fasta)                  
            file_of[OutputFormat::Kraken2Fasta] = kraken2_fasta
        end
        
        if params[:output][:comparison]
            comparison_file                     = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_comparison.tsv",   OutputFormat::Comparison)
            file_of[OutputFormat::Comparison]   = comparison_file
        end
        
        if params[:output][:dada2_taxonomy]
            dada2_taxonomy_fasta                        = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_dada2_taxonomy.fas",   OutputFormat::Dada2TaxonomyFasta)   
            file_of[OutputFormat::Dada2TaxonomyFasta]   = dada2_taxonomy_fasta
        end
        
        if params[:output][:dada2_species]
            dada2_species_fasta                         = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}_dada2_species.fas",   OutputFormat::Dada2SpeciesFasta)
            file_of[OutputFormat::Dada2SpeciesFasta]    = dada2_species_fasta
        end

        return file_of
    end

    def self.write_to_files(file_of:, taxonomic_info:, nomial:, params:, data:)

        file_of.each do |output_file_class, file|

            if output_file_class == OutputFormat::Comparison
                syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [TaxonomyHelper.get_source_db(params[:taxonomy])])
                OutputFormat::Comparison.write_to_file(file: file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms_of_taxonomy: syn.synonyms_of_taxonomy, used_taxonomy: TaxonomyHelper.get_source_db(params[:taxonomy]))
                # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms_of_taxonomy: syn.synonyms_of_taxonomy)
            end
            
            data.each do |datum|

                if output_file_class == OutputFormat::Tsv
                    OutputFormat::Tsv.write_to_file(tsv: file, data: datum, taxonomic_info: taxonomic_info)

                elsif output_file_class == OutputFormat::Fasta
                    OutputFormat::Fasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info)

                elsif output_file_class == OutputFormat::Qiime2Taxonomy
                    OutputFormat::Qiime2Taxonomy.write_to_file(file: file, taxonomic_info: taxonomic_info, identifier: datum[:identifier])

                elsif output_file_class == OutputFormat::Qiime2TaxonomyFasta
                    OutputFormat::Qiime2TaxonomyFasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info)

                elsif output_file_class == OutputFormat::Kraken2Fasta
                    OutputFormat::Kraken2Fasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info)

                elsif output_file_class == OutputFormat::Dada2TaxonomyFasta
                    OutputFormat::Dada2TaxonomyFasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info)

                elsif output_file_class == OutputFormat::Dada2SpeciesFasta
                    OutputFormat::Dada2SpeciesFasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info)
                end
            end
        end
    end

    def self.write_marshal_file(dir:, file_name:, data:)
        marshal_dump_file_name = dir + file_name
        data_dump = Marshal.dump(data)
        
        File.open(marshal_dump_file_name, 'wb') { |f| f.write(data_dump) }
    end
end