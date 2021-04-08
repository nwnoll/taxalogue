# frozen_string_literal: true

class NcbiDownloadCheckHelper

    PRECEDENCE_OF = {
        'true' => 2,
        'false' => 1,
        "" => 0,
        "[]" => 0,
    }
    def self.ask_user_about_download_dirs(params, only_successful = true)
        dirs = FileManager.directories_with_name_of(dir: NcbiGenbankConfig::DOWNLOAD_DIR, dir_name: 'release')
        return nil if DownloadCheckHelper.is_nil_or_empty?(dirs)
    
        # success = DownloadInfoParser.download_was_successful?
        releases = []

        division_codes = NcbiDivision.codes_for_taxon(params)
        dirs.each do |dir|
            success         = DownloadInfoParser.download_was_successful?(dir + ".#{NcbiGenbankJob::DOWNLOAD_INFO_NAME}")
            dirs_for_code   = Hash.new { |h, k| h[k] = Hash.new}
            release_name    = dir.basename            
            release         = OpenStruct.new(name: dir.basename.to_s, base_dir: dir, success: success)
            
            failed_divisions    = []
            has_all_divisions   = true
            division_codes.each do |division_code|
                division_dirs = FileManager.directories_with_name_of(dir: dir, dir_name:division_code)
                dirs_for_code[division_code] = division_dirs.first
                
                if DownloadCheckHelper.is_nil_or_empty?(division_dirs)
                    failed_divisions.push(division_code)
                    has_all_divisions = false
                end

            end

            release.dirs_for_code       = dirs_for_code
            release.failed_divisions    = failed_divisions
            release.has_all_divisions   = has_all_divisions

            releases.push(release)
        end

        releases = releases.sort_by { |e| [PRECEDENCE_OF[e.success.to_s], PRECEDENCE_OF[e.has_all_divisions.to_s], _get_release_number(e.name)] }.reverse
        releases = releases.select { |e| e.success } if only_successful
        releases = releases.select { |e| e.has_all_divisions }
        ## TODO:
        ## NEXT:
        ## if the already downloaded version is the current version and
        ## it has been done for mam or rod, but the next query is inv
        ## then it will download the rlease again but overwrites
        ## the already downloaded mam and rod
        ## maybe give the Job an array of divisons to download?
        return nil if DownloadCheckHelper.is_nil_or_empty?(releases)

        has_dirs_for_each_division = !(dirs_for_code.values.any? { |e| DownloadCheckHelper.is_nil_or_empty?(e) })
        return nil unless has_dirs_for_each_division

        release_number = NcbiDownloadCheckHelper.get_current_genbank_release_number


        DownloadCheckHelper.is_nil_or_empty?(data)
        exit

    
    
        puts "You have already downloaded data for the taxon #{params[:taxon]}"
        # puts "Sequences for #{params[:taxon]} are available in: #{selected_download_dir.to_s}"
        # puts "The latest already downloaded version is #{last_download_days} days old"
        # puts
        puts "Do you want to use the latest already downloaded version? [Y/n]"
        puts "Otherwise a new download will start"
    
    
        # nested_dir_name = FileManager.dir_name_of(dir: selected_download_dir)
        # download_dir = selected_download_dir + nested_dir_name
    
        user_input  = gets.chomp
        use_latest_download = (user_input =~ /y|yes/i) ? true : false
    
        return use_latest_download ? selected_download_dir : nil
    end
    
    def self.get_current_genbank_release_number
        file_path = NcbiGenbankConfig::DOWNLOAD_DIR + '.current_genbank_release_number.txt'
        
        begin
            downloader = HttpDownloader2.new(address: NcbiGenbankConfig::CURRENT_RELEASE_ADDRESS, destination: file_path)
            downloader.run
        rescue StandardError
            return nil
        end
    
        ## works until we reach Genbank release 1000
        file_content = File.read(file_path, 3) if File.file?(file_path)
        
        return file_content
    end

    def self._get_release_number(str)
        str[-3..-1].to_i
    end
end