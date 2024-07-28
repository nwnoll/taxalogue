# frozen_string_literal: true

class MiscHelper
    PASTEL                          = Pastel.new
    GENBANK_MARKER_FILES_DIR        = ".genbank_files_with_markers"
    GENBANK_MARKER_FILES_DIR_PATH   = Pathname.new(GENBANK_MARKER_FILES_DIR)
    GENBANK_MARKER_INFO_FILE        = ".config/genbank_markers.json"

    def self.get_lineage_from_midori_header(header)
        lineage = []
        GbifTaxonomy.possible_ranks.each_with_index do |r, i|
            header =~ /;#{r}_(.*?)_/    
            lineage[i] = $1
        end
            
        return lineage        
    end

    def self.json_file_to_hash(file_name)
        file = File.read(file_name)
        hash = JSON.parse(file)
    
        return hash
    end

    def self.fasta_gzip_to_hash(fasta_gzip)
        seq_of = Hash.new("")
        header = nil
        found = false
        fasta_gzip.each do |line|
            line.chomp!

            if line =~ /^>/
                header = line
            else
                seq_of[header] += line
            end
            # if line =~ /^>KF848213.1./
            #     header = line
            #     found = true 
            # else
            #     if found
            #         seq_of[header] += line
            #         break
            #     end
            # end
        end

        return seq_of
    end

    def self.fasta_to_hash(file_name)
        file = File.open(file_name, 'r')
        seq_of = Hash.new("")
        header = nil
        file.each do |line|
            line.chomp!
            if line =~ "^>"
                header = line
            else
                seq_of[header] += line
            end
        end

        return seq_of
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
        has_download_action = params[:download].any?    ? 1 : 0
        has_classify_action = params[:classify].any?    ? 1 : 0
        has_setup_action    = params[:setup].any?       ? 1 : 0
        has_update_action   = params[:update].any?      ? 1 : 0

        if (has_download_action + has_classify_action + has_setup_action + has_update_action) > 1
            return true
        else
            return false
        end
    end

    def self.custom_shapefile_params_count(params)
        set_params_count = 0
        set_params_count += params[:region][:custom_shapefile]              ? 1 : 0
        set_params_count += params[:region][:custom_shapefile_attribute]    ? 1 : 0
        set_params_count += params[:region][:custom_shapefile_values]       ? 1 : 0

        return set_params_count
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
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Tsv)                    if params[:output][:table]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Fasta)                  if params[:output][:fasta]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Comparison)             if params[:output][:comparison]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Qiime2Taxonomy)         if params[:output][:qiime2]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Qiime2TaxonomyFasta)    if params[:output][:qiime2]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Kraken2Fasta)           if params[:output][:kraken2]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Dada2TaxonomyFasta)     if params[:output][:dada2_taxonomy]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Dada2SpeciesFasta)      if params[:output][:dada2_species]
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::SintaxFasta)            if params[:output][:sintax]
    end

    def self.create_output_files(file_manager:, query_taxon_name:, file_name:, params:, source_db:)

        file_of = Hash.new
        
        
        if source_db == "ncbi"
            file_base = "#{query_taxon_name}_#{file_name.basename('.*').sub_ext('')}_#{source_db}"
        else
            file_base = "#{query_taxon_name}_#{file_name.basename('.*')}_#{source_db}"
        end


        if params[:output][:table]
            tsv                         = file_manager.create_file("#{file_base}_output.tsv", OutputFormat::Tsv)
            file_of[OutputFormat::Tsv]  = tsv
        end

        if params[:output][:fasta]
            fasta                           = file_manager.create_file("#{file_base}_output.fas", OutputFormat::Fasta)
            file_of[OutputFormat::Fasta]    = fasta
        end

        if params[:output][:qiime2]
            qiime2_taxonomy                         = file_manager.create_file("#{file_base}_qiime2_taxonomy.txt", OutputFormat::Qiime2Taxonomy)
            file_of[OutputFormat::Qiime2Taxonomy]   = qiime2_taxonomy
        end
        
        if params[:output][:qiime2] 
            qiime2_fasta                                = file_manager.create_file("#{file_base}_qiime2_taxonomy.fas", OutputFormat::Qiime2TaxonomyFasta)
            file_of[OutputFormat::Qiime2TaxonomyFasta]  = qiime2_fasta
        end

        if params[:output][:kraken2]
            kraken2_fasta                       = file_manager.create_file("#{file_base}_kraken2.fas", OutputFormat::Kraken2Fasta)                  
            file_of[OutputFormat::Kraken2Fasta] = kraken2_fasta
        end
        
        if params[:output][:comparison]
            comparison_file                     = file_manager.create_file("#{file_base}_comparison.tsv",   OutputFormat::Comparison)
            file_of[OutputFormat::Comparison]   = comparison_file
        end
        
        if params[:output][:dada2_taxonomy]
            dada2_taxonomy_fasta                        = file_manager.create_file("#{file_base}_dada2_taxonomy.fas",   OutputFormat::Dada2TaxonomyFasta)   
            file_of[OutputFormat::Dada2TaxonomyFasta]   = dada2_taxonomy_fasta
        end

        if params[:output][:dada2_species]
            dada2_species_fasta                         = file_manager.create_file("#{file_base}_dada2_species.fas",   OutputFormat::Dada2SpeciesFasta)
            file_of[OutputFormat::Dada2SpeciesFasta]    = dada2_species_fasta
        end

        if params[:output][:sintax]
            sintax                              = file_manager.create_file("#{file_base}_sintax.fas",   OutputFormat::SintaxFasta)
            file_of[OutputFormat::SintaxFasta]  = sintax
        end


        return file_of
    end

    def self.write_to_files(file_of:, taxonomic_info:, nomial:, params:, data:, batch: false)
        file_of.each do |output_file_class, file|

            if batch
                source_db = TaxonomyHelper.get_source_db(params[:taxonomy])
                data.each_with_index do |datum, i|
                    if output_file_class == OutputFormat::Tsv
                        OutputFormat::Tsv.write_to_file(tsv: file, data: datum, taxonomic_info: taxonomic_info[i])

                    elsif output_file_class == OutputFormat::Fasta
                        OutputFormat::Fasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info[i])
                    
                    elsif output_file_class == OutputFormat::Comparison
                      syn = Synonym.new(accepted_taxon: taxonomic_info[i], sources: [source_db])
                      OutputFormat::Comparison.write_to_file(file: file, nomial: nomial[i], accepted_taxon: taxonomic_info[i], synonyms_of_taxonomy: syn.synonyms_of_taxonomy, used_taxonomy: source_db)
                    end
                end

                next
            end



            if output_file_class == OutputFormat::Comparison
                if params[:taxonomy][:unmapped]
                    ## TODO:
                    #  Change so that maybe there will be all possible synonyms from all possible sources
                    #  or that the synonyms of the chosen taxonomy? but ther is no taxonomy chosen
                    #  it is NcbiTaxonomy in the compariosn file since it is in the else...
                    syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [TaxonomyHelper.get_source_db(params[:taxonomy])])
                else
                    syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [TaxonomyHelper.get_source_db(params[:taxonomy])])
                end
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

                elsif output_file_class == OutputFormat::SintaxFasta
                    OutputFormat::SintaxFasta.write_to_file(fasta: file, data: datum, taxonomic_info: taxonomic_info)
                end

            end
        end
    end

    def self.write_marshal_file(dir:, file_name:, data:)
        marshal_dump_file_name = dir + file_name
        data_dump = Marshal.dump(data)
        File.open(marshal_dump_file_name, 'wb') { |f| f.write(data_dump) }
    end

    def self.is_gz_valid?(file_name)
        return false unless file_name
        return false unless File.file?(file_name)
        f = File.open(file_name, 'r')
        return false unless f


        valid = true
        begin 
            Zlib::GzipReader.zcat(f)
        rescue Zlib::Error
            valid = false
        end

        
        f.close
        return valid
    end

    def self.get_error_gzip_files(file_names)
        error_files = []
        file_names.each do |file_name|
            puts file_name
            f = File.open(file_name, 'r')
            begin 
                Zlib::GzipReader.zcat(f)
            rescue => e
                puts "true"
                p e
                error_files.push(file_name)
            end
            puts
            f.close
        end


        return error_files
    end


    # goes through every file in the dir end checks if a file 
    # has a certain marker
    def self.search_for_markers_in_genbank_files(marker_objects:, dir_name:)
        dir         = Pathname.new(dir_name)
        files       = dir.glob('*')

            
        genbank_file_release = dir.ascend.to_a[1].basename
        FileUtils.mkdir_p "#{GENBANK_MARKER_FILES_DIR}/#{genbank_file_release}"
        sleep 0.1
        

        searchterms_of = Marker.searchterms_of
        searchterms = []
        searchterms_per_marker_tag = Hash.new


        marker_objects.each do |marker_object|
            current_searchterms = []
            searchterms_of[marker_object.marker_tag][:ncbi].each do |searchterm|
                mod_searchterm = searchterm.gsub('^', '\"')
                mod_searchterm.gsub!('$', '\"')
                searchterms.push(mod_searchterm)
                current_searchterms.push(mod_searchterm)
            end
            searchterms_per_marker_tag[marker_object.marker_tag] = Regexp.new(current_searchterms.join('|').prepend('(').concat(')'), Regexp::IGNORECASE)
        end
        regexes = Regexp.new(searchterms.join('|').prepend('(').concat(')'), Regexp::IGNORECASE)

        
        Parallel.map(files, in_processes: $params[:num_cores]) do |file|
            Zlib::GzipReader.open(file) do |gz_file|
                found_marker_tags = []
                gz_file.each_line do |line|
                    if line =~ /^\s{21}\/gene=/
                        if line =~ regexes
                            searchterms_per_marker_tag.each do |marker_tag, regex_for_marker|
                                if $1 =~ regex_for_marker
                                    found_marker_tags.push(marker_tag.to_s)
                                end
                            end

                            break
                        end
                    end
                end


                fo = File.open("#{GENBANK_MARKER_FILES_DIR}/#{genbank_file_release}/#{file.basename.sub_ext('').sub_ext('')}", 'w')
                found_marker_tags.each do |found_marker|
                    fo.puts "#{file}\t#{found_marker}\ttrue"
                end


                marker_tags = []
                marker_objects.each { |marker_object| marker_tags.push(marker_object.marker_tag.to_s) }
                (marker_tags - found_marker_tags).each do |not_found_marker_tag|
                    fo.puts "#{file}\t#{not_found_marker_tag}\tfalse"
                end
                fo.close
            end
        end    
    end


    ## collects found markers in GenBank files into one file
    def self.create_genbank_marker_info_file
        markers_of = Hash.new { |h1,k1| h1[k1] = Hash.new }
        
        
        files = GENBANK_MARKER_FILES_DIR_PATH.glob("**/*")
        files.each do |file|
            next unless File.file?(file)


            fi = File.open(file, 'r')
            fi.each do |line|
                line.chomp!
                line                        =~ /^(.*?)\t(.*?)\t(.*)/
                genbank_full_relative_path  = $1
                marker                      = $2
                marker_found                = $3 == 'true' ? true : false 


                markers_of[genbank_full_relative_path][marker] = marker_found
            end
        end


        json_markers_of = markers_of.to_json
        fo              = File.open(GENBANK_MARKER_INFO_FILE, 'w')
        fo.puts json_markers_of
    end


    def self.get_genbank_marker_info
        if File.file?(GENBANK_MARKER_INFO_FILE)
            return json_file_to_hash(GENBANK_MARKER_INFO_FILE)
        else
            return nil
        end
    end
end
