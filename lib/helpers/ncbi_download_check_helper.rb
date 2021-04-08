# frozen_string_literal: true

class NcbiDownloadCheckHelper
    def self.ask_user_about_download_dirs(params, only_successful = false)
        dirs = FileManager.directories_with_name_of(dir: NcbiGenbankConfig::DOWNLOAD_DIR, dir_name: 'release')
        return nil if DownloadCheckHelper.is_nil_or_empty?(dirs)
    
        # success = DownloadInfoParser.download_was_successful?
    
        division_codes = NcbiDivision.codes_for_taxon(params)
        dirs_for_code = Hash.new { |h, k| h[k] = Hash.new}
        dirs.each do |dir|
            release_name = dir.basename
            success = DownloadInfoParser.download_was_successful?(dir + ".#{NcbiGenbankJob::DOWNLOAD_INFO_NAME}")
            
            if only_successful
                next unless success
            end

            division_codes.each do |division_code|
                division_dirs = FileManager.directories_with_name_of(dir: dir, dir_name:division_code)
                dirs_for_code[release_name][division_code] = division_dirs.first
            end
        end

        ## TODO:
        ## NEXT:
        ## dirs is an array of all possible release downloads
        ## e.g. release 242, 241 etc....
        ## i need to knwo if each release has alle the needed division dirs
        ## and the corresponding path of each of these dirs
        ## maybe create a struct?
        # OpenStruct.new(
        #     name: 'release241',
        #     dirs_for_code: Hash.new,
        #     success: true,
        #     failed_divisons: ['mam', 'rod'],
        # )

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
end