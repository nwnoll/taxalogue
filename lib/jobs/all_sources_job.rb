# frozen_string_literal: true

class AllSourcesJob
    attr_reader :jobs

    def initialize(jobs:)
        @jobs = jobs
    end

    def run
        results = []
        jobs.each do |job|
            results.push(job.run)
        end
        byebug
    end

    
end