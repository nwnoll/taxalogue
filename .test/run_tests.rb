base_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
lib_dir  = File.join(base_dir, ".lib")
test_dir = File.join(base_dir, ".test")

$LOAD_PATH.unshift(lib_dir)

abort 'Need to set environment variable to test: TAXALOGUE_MOUDE=test bundle exec ruby .test/run_tests.rb' unless ENV['TAXALOGUE_MODE'] == 'test'
require_relative '../.requirements'

exit Test::Unit::AutoRunner.run(true, test_dir)
