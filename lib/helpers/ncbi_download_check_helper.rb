# frozen_string_literal: true

class NcbiDownloadCheckHelper

    PRECEDENCE_OF = {
        ## although 0 is higher
        ## i reverse the resulting list later
        'true' => 2,
        'false' => 1,
        "" => 0,
        "[]" => 0,
    }
    def self.ask_user_about_download_dirs(params, only_successful = true)

        ## TODO:
        ## disable search temporarily to always download
        ## delete after dataset download
        return nil if params[:create][:all]
        ##
        
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
            
            missing_divisions   = []
            has_all_divisions   = true
            division_codes.each do |division_code|
                division_dirs = FileManager.directories_with_name_of(dir: dir, dir_name:division_code)
                dirs_for_code[division_code] = division_dirs.first
                
                if DownloadCheckHelper.is_nil_or_empty?(division_dirs)
                    missing_divisions.push(division_code)
                    has_all_divisions = false
                end

            end

            release.dirs_for_code       = dirs_for_code
            release.missing_divisions   = missing_divisions
            release.has_all_divisions   = has_all_divisions

            releases.push(release)
        end

        releases = releases.sort_by { |e| [PRECEDENCE_OF[e.success.to_s], PRECEDENCE_OF[e.has_all_divisions.to_s], _get_release_number(e.name)] }.reverse
        releases = releases.select { |e| e.success } if only_successful
        return nil if DownloadCheckHelper.is_nil_or_empty?(releases)

        current_release_number = _get_release_number(NcbiDownloadCheckHelper.get_current_genbank_release_number)

        releases.each do |release|
            release_number_of_release = _get_release_number(release.name)
            if current_release_number == release_number_of_release
                release.is_current_release = true
            else
                release.is_current_release = false
            end
        end

        current_and_complete_release = releases.select { |r| r.is_current_release && r.has_all_divisions && r.success }.first
        return current_and_complete_release unless current_and_complete_release.nil? ## success!
        
        current_incomplete_release = releases.select { |r| r.is_current_release && r.success }.first
        if current_incomplete_release
            puts "You already have the latest Genbank release"
            puts "Since it is not complete for your queried Taxon, the download for the following divisions will start soon"
            puts current_incomplete_release.missing_divisions
            puts
            return current_incomplete_release
        end

        successful_releases                 = releases.select { |r| r.success }
        complete_releases                   = releases.select { |r| r.has_all_divisions }
        successful_and_complete_releases    = releases.select { |r| r.has_all_divisions && r.has_all_divisions }

        sorted_successful_and_complete_releases = successful_and_complete_releases.sort_by { |e| _get_release_number(e.name) }.reverse
        successful_and_complete_release = sorted_successful_and_complete_releases.first
        if successful_and_complete_release
            suc_comp_release_num = _get_release_number(successful_and_complete_release.name)
            puts "You already have downloaded a Genbank release with all needed divisions"
            puts current_release_number == 0 ? "Current release number could not be identified\nYour old release version is #{suc_comp_release_num}" : "However, it is not the latest version\nYou have version #{suc_comp_release_num}, the latest version is #{current_release_number}"
            puts
            puts "Do you want to use your old version? [Y/n]"
            puts "Otherwise a new download will start"

            user_input  = gets.chomp
            use_old_version = (user_input =~ /y|yes/i) ? true : false
        
            return use_old_version ? successful_and_complete_release : nil
        else
            return nil
        end
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
        return 0 unless str

        str[-3..-1].to_i
    end
end