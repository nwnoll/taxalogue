# frozen_string_literal: true

class BoldDownloadCheckHelper

    RJUST_LEVEL_ONE = " " * 6
    RJUST_LEVEL_TWO = " " * 10

    def self.select_from_download_dirs(dirs:)

        # precedence:
        ## only :same_taxon_found && :higher_taxon_found
        ## successfull highest precendence, after that comes distinction between same_taxon and higher_taxon
        ## after that comes most recent version and
    
        precedence_of = {
            ## 0 higher precedence
            'true' => 0,
            'false' => 1,
            "" =>  9, # nil
    
            'same_taxon_found' => 0,
            'higher_taxon_found' => 1,
            'lower_taxon_found' => 2,
            'taxon_not_found' => 3,
            'dir_name_not_found' => 3,
    
            'not_versioned' => DateTime.new(1900)
        }
        only_dirs = dirs.map { |ary| ary[0] }
    
        desc_dirs_by_datetime = FileManager.sort_by_datetime(dirs: only_dirs, mode: 'desc')
        
        sorted = dirs.sort_by do |dir_and_state|
            dir, state  = dir_and_state
            file_path   = dir + ".#{BoldJob::DOWNLOAD_INFO_NAME}"
        
            success = DownloadInfoParser.download_was_successful?(file_path)
        
            datetime = FileManager.datetime_of(dir: dir)
            datetime = precedence_of[datetime] if precedence_of.key?(datetime)
            
            ## defines precedence
            ## success | download_state | datetime of di
            [precedence_of[success.to_s], precedence_of[state.to_s], desc_dirs_by_datetime.index(dir)]
        end
    
        same_or_higher_taxa_sorted = sorted.select { |dir_and_state| dir_and_state.last == :same_taxon_found || dir_and_state.last == :higher_taxon_found  }
    
        return same_or_higher_taxa_sorted.first
    end

    def self.download_dirs_for_taxon(params:, dirs:, only_successful: true)
        taxon_dirs = []
        dirs.each do |dir|
            taxon_download_status = BoldDownloadCheckHelper.taxon_download_status(dir: dir, params: params)
            taxon_dirs.push([dir, taxon_download_status]) unless taxon_download_status == :dir_name_not_found || taxon_download_status == :taxon_not_found
        end
    
        if only_successful
            successful_downloads = taxon_dirs.select do |dir_and_state|
                dir, state = dir_and_state
                file_path   = dir + ".#{BoldJob::DOWNLOAD_INFO_NAME}"
                
                DownloadInfoParser.download_was_successful?(file_path)
            end
        end
    
        return only_successful ? successful_downloads : taxon_dirs
    end

    def self.taxon_download_status(dir:, params:)

        taxon_query_object = params[:taxon_object]
    
        record_for_dir_name = nil
        taxon_object_from_marshal_dump = DownloadCheckHelper.get_taxon_record_from_marshal_dump(dir)
        if taxon_object_from_marshal_dump
            ## since there are some differences between the taxonomies the taxon_object should only
            ## come from the same taxonomy as ther user specified taxonomy
            if taxon_object_from_marshal_dump.is_a?(GbifTaxonomy) && (params[:taxonomy][:gbif] || params[:taxonomy][:gbif_backbone])
                record_for_dir_name = taxon_object_from_marshal_dump
            elsif taxon_object_from_marshal_dump.is_a?(OpenStruct) && params[:taxonomy][:ncbi]
                record_for_dir_name = taxon_object_from_marshal_dump
            else
                record_for_dir_name = nil
            end
        else
            dir_name = FileManager.dir_name_of(dir: dir)
            record_for_dir_name = TaxonHelper.get_taxon_record(params, dir_name)
        end
    
        return :dir_name_not_found if record_for_dir_name.nil?
    
        if taxon_query_object.canonical_name == record_for_dir_name.canonical_name
            return :same_taxon_found
        
        elsif record_for_dir_name.taxon_rank
          
            ## works if taxon query is lower than dir_name
            ## e.g user wants Lentulidae, but has already downloaded seqs for Orthoptera
            return :higher_taxon_found if taxon_query_object.public_send(TaxonomyHelper.latinize_rank(record_for_dir_name.taxon_rank)) == record_for_dir_name.canonical_name
            
            ## works if taxon query is higher than dir name
            ## e.g. user wants Arthopoda, but has already downloaded seqs for Insecta  
            return :lower_taxon_found if record_for_dir_name.public_send(TaxonomyHelper.latinize_rank(taxon_query_object.taxon_rank)) == taxon_query_object.canonical_name
            
            ## did find no matches
            return :taxon_not_found
        else # no rank
            return :taxon_not_found
        end
    end

    def self.ask_user_about_download_dirs(params, only_successful = false)
        MiscHelper.OUT_header "Looking for BOLD database downloads"
        puts

        dirs = FileManager.directories_of(dir: BoldConfig::DOWNLOAD_DIR)
        return nil if DownloadCheckHelper.is_nil_or_empty?(dirs)
    
        taxon_dirs = BoldDownloadCheckHelper.download_dirs_for_taxon(params: params, dirs: dirs, only_successful: only_successful)
        return nil if DownloadCheckHelper.is_nil_or_empty?(taxon_dirs)
    
        selected_download_dir_and_state = BoldDownloadCheckHelper.select_from_download_dirs(dirs: taxon_dirs)
        return nil if DownloadCheckHelper.is_nil_or_empty?(selected_download_dir_and_state)
    
        selected_download_dir, selected_download_state = selected_download_dir_and_state
        last_download_days = FileManager.is_how_old?(dir: selected_download_dir)
        return nil if last_download_days.nil?

        puts "You have already downloaded data for the taxon #{params[:taxon]}"
        puts "Sequences for #{params[:taxon]} are available in: #{selected_download_dir.to_s}"
        puts "The latest already downloaded version is #{last_download_days} days old"
        puts
        MiscHelper.OUT_question "Do you want to use the latest already downloaded version? [Y/n]"
    
        # nested_dir_name = FileManager.dir_name_of(dir: selected_download_dir)
        # download_dir = selected_download_dir + nested_dir_name
        
        user_input  = gets.chomp
        use_latest_download = (user_input =~ /y|yes/i) ? true : false
    
        return use_latest_download ? selected_download_dir : nil
    end

    def self.create_download_info_for_result_dir(download_file_managers:, result_file_manager:, source:, release_info_struct: nil)
        download_info_str = source::DOWNLOAD_INFO_NAME

        result_dl_info_public_name = result_file_manager.dir_path + download_info_str
        result_dl_info_hidden_name = result_file_manager.dir_path + ".#{download_info_str}"

        root_download_dir = download_file_managers.first.base_dir
        dl_tree_path_hidden = Pathname.new(root_download_dir + ".#{source::DOWNLOAD_INFO_TREE_NAME}")
        
        failures = DownloadInfoParser.get_download_failures(dl_tree_path_hidden)
        success = failures.empty? ? true : false

        paths = [result_dl_info_public_name, result_dl_info_hidden_name]
        paths.each do |path|
            file = File.open(path, 'w')
            download_file_managers.each_with_index do |download_file_manager, i|
                file.puts 'data:' if i == 0
                file.puts "#{download_file_manager.base_dir.to_s}; success: #{success}".dup.prepend(RJUST_LEVEL_ONE) if i == 0

                sub_directory_success = download_file_manager.status == 'success' ?  true : false
                file.puts "#{download_file_manager.dir_path.to_s}; success: #{sub_directory_success}".dup.prepend(RJUST_LEVEL_TWO)
            end
        end
    end
end