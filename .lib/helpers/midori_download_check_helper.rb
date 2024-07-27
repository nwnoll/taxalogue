# frozen_string_literal: true

class MidoriDownloadCheckHelper
    def self.ask_user_about_download_dirs(params)
        MiscHelper.OUT_header "Looking for MIDORI database downloads"
        puts

        dirs = FileManager.directories_of(dir: MidoriConfig::DOWNLOAD_DIR)
        current_release = nil
        dirs.each do |dir|
            if dir == MidoriConfig::DOWNLOAD_DIR + MidoriConfig::RELEASES[:current]
                success = DownloadInfoParser.download_was_successful?(dir + ".#{MidoriJob::DOWNLOAD_INFO_NAME}")
                
                current_release = dir if success
                
                break ## maybe multiple instances of download dir?
            end
        end

        if current_release
            ## TODO:
            ## NEXT
            ## Check for download success
            
            puts "You already have the latest MIDORI release"
            puts
            return current_release
        else
            return nil
        end
    end
end
