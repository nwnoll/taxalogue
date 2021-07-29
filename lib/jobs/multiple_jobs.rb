# frozen_string_literal: true

class MultipleJobs
    attr_reader :jobs, :download_only

    def initialize(jobs:, params:)
        @jobs           = jobs
        @download_only  = params[:download].any?
    end

    def run
        results_of = Hash.new

        # force_download = true if jobs.size > 1
        jobs.each do |job|
            results_of[job.class] = job.run
        end

        puts
        puts "Output locations:"
        result_file_manager = nil
        count_cant_classify = 0
        results_of.each do |key, value|
            result_file_manager     = value.first
            download_file_managers  = value.last
            
            if value.last == :cant_classify
                count_cant_classify += 1
                next
            end

            download_file_managers.each_with_index do |download_file_manager, i|
                if key == BoldJob
                    download_dir_path = download_file_manager.base_dir
                    puts download_dir_path if i == 0
                else
                    download_dir_path = download_file_manager.dir_path
                    puts download_dir_path
                end
            end
        end

        if count_cant_classify == results_of.keys.size
            puts 'No output' unless download_only
            FileUtils.rmdir(result_file_manager.dir_path)

            return :failure
        else
            unless download_only
                DownloadCheckHelper.write_marshal_file(dir: result_file_manager.dir_path, data: result_file_manager, file_name: '.result_file_manager.dump')
                puts result_file_manager.dir_path
            end
            
            return :success
        end
    end
end