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
        results_of.each do |key, value|
            result_file_manager     = value.first
            download_file_managers  = value.last

            download_file_managers.each_with_index do |download_file_manager, i|
                if key == BoldJob
                    download_dir_path = download_file_manager.base_dir
                    puts download_dir_path if i == 0
                else
                    download_dir_path = download_file_manager.dir_path
                    puts download_dir_path
                end
            end
            # pp download_file_managers
        end

        puts result_file_manager.dir_path unless download_only
    end
end