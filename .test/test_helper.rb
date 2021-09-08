# frozen_string_literal: true

abort 'Need to set environment variable to test: TAXALOGUE_MODE=test bundle exec ruby .test/run_tests.rb' unless ENV['TAXALOGUE_MODE'] == 'test'

require './.requirements'