# frozen_string_literal: true

require_relative '../test_helper'

class TestRegionHelper < Test::Unit::TestCase
    include GeoUtils
    
    def test_check_valid_names
        valid_names = all_country_names
        
        assert_raise (SystemExit) { RegionHelper.check_valid_names(valid_names, ['Germany', 'Ausria']) }
        assert_nothing_raised (SystemExit) { RegionHelper.check_valid_names(valid_names, ['Germany']) }
        assert_nothing_raised (SystemExit) { RegionHelper.check_valid_names(valid_names, ['Germany', 'Austria']) }
        assert_nothing_raised (SystemExit) { RegionHelper.check_valid_names(valid_names, ['Russia']) }
    end
end