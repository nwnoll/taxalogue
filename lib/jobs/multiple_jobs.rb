# frozen_string_literal: true

class MultipleJobs
    attr_reader :jobs, :file_manager

    def initialize(jobs:, file_manager:)
        @jobs           = jobs
        @file_manager   = file_manager
    end

    def run
        file_manager.create_dir
        
        jobs.each do |job|
            job.run
        end

        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Tsv)
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Fasta)
        FileMerger.run(file_manager: file_manager, file_type: OutputFormat::Comparison)
    end

    
end