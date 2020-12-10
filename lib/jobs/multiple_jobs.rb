# frozen_string_literal: true

class MultipleJobs
    attr_reader :jobs

    def initialize(jobs:)
        @jobs = jobs
    end

    def run
        jobs.each do |job|
            job.run
        end
    end

    
end