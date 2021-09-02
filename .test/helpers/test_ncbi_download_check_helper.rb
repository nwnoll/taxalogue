
# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiDownloadCheckHelper < Test::Unit::TestCase

    def test_get_current_genbank_release_number
        assert_equal String, NcbiDownloadCheckHelper.get_current_genbank_release_number.class
    end
end