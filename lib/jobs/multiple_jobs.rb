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


            # pp download_file_managers
            if key == BoldJob
                download_dir_path = download_file_managers.first.base_dir
            else
                download_dir_path = download_file_managers.first.dir_path
            end

            puts download_dir_path
        end

        puts result_file_manager.dir_path unless download_only
    end
end