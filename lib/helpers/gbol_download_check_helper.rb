# frozen_string_literal: true

class GbolDownloadCheckHelper
    def self.ask_user_about_gbol_download_dirs(params)
        MiscHelper.OUT_header "Looking for GBOL database downloads"

        dirs = FileManager.directories_of(dir: GbolConfig::DOWNLOAD_DIR)
        current_release = nil
        dirs.each do |dir|
            if dir == GbolConfig::DOWNLOAD_DIR + GbolConfig::RELEASES[:current]
                success = DownloadInfoParser.download_was_successful?(dir + ".#{GbolJob::DOWNLOAD_INFO_NAME}")
                
                current_release = dir if success
                break ## maybe multiple instances of download dir?
            end
        end


        if current_release
            ## NEXT
            ## TODO:
            ## Check for download success
            
            puts "You already have the latest GBOL release"
            return current_release
        else
            puts "A new GBOL release is available"
            MiscHelper.OUT_question "Do you want to download the new release? [Y/n]"
            user_input  = gets.chomp
            download_new_release = (user_input =~ /y|yes/i) ? true : false
            if download_new_release
                return nil
            else
                if dirs.empty?
                    puts "No releases available. New GBOL release will be downloaded."
                    return nil
                else
                    3.times do
                        puts "Please specify one of the following GBOL releases:"
                        dirs.each { |dir| puts dir.to_s }

                        user_input  = gets.chomp
                        user_path = Pathname.new(user_input)
                        if dirs.include?(user_path)
                            puts "You specified #{user_input}"
                            return user_path
                        else
                            next
                        end

                        puts "No release specified. New GBOL dataset will be downloaded"
                        
                        return nil
                    end
                end
            end
        end
    end
end