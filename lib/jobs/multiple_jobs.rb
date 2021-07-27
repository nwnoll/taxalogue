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

        puts "Output locations:"
        results_of.each do |key, value|
            result_file_manager     = value.first
            download_file_managers  = value.last
            
            if download_only
                puts download_file_managers.first.base_dir
            else
                puts download_file_managers.first.base_dir
                puts result_file_manager.dir_path
            end
            puts
        end
    end

    
end