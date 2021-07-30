# frozen_string_literal: true

class MultipleJobs
    attr_reader :jobs, :download_only, :params

    def initialize(jobs:, params:)
        @jobs           = jobs
        @params         = params
        @download_only  = params[:download].any?
    end

    def run
        results_of = Hash.new

        # force_download = true if jobs.size > 1
        bold_dir = nil
        gbol_dir = nil
        ncbi_dir = nil
        jobs.each do |job|
            if job.class == BoldJob
                bold_dir = BoldDownloadCheckHelper.ask_user_about_download_dirs(params, only_successful = false)
            elsif job.class == GbolJob
                gbol_dir = GbolDownloadCheckHelper.ask_user_about_gbol_download_dirs(params)
            elsif job.class == NcbiGenbankJob
                ncbi_dir = NcbiDownloadCheckHelper.ask_user_about_download_dirs(params, only_successful = true)
            end
        end
    
        jobs.each do |job|
            if job.class == BoldJob
                results_of[job.class] = job.run(bold_dir)
            elsif job.class == GbolJob
                results_of[job.class] = job.run(gbol_dir)
            elsif job.class == NcbiGenbankJob
                results_of[job.class] = job.run(ncbi_dir)
            end
        end

        puts
        puts MiscHelper.OUT_header "Output locations:"
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
            puts MiscHelper.OUT_error 'No output' unless download_only
            FileUtils.rmdir(result_file_manager.dir_path)

            return :failure
        else
            unless download_only
                DownloadCheckHelper.write_marshal_file(dir: result_file_manager.dir_path, data: result_file_manager, file_name: '.result_file_manager.dump')
                puts MiscHelper.OUT_success result_file_manager.dir_path
            end
            
            return :success
        end
    end
end