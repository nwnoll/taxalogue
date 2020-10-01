# frozen_string_literal: true

require_relative '../test_helper'

class TestStringFormatting < Test::Unit::TestCase

      def test__tsv_header
            assert_equal "identifier\tkingdom\tphylum\torder\tfamily\tgenus\tcanonical_name\tsequence", OutputFormat::Tsv._tsv_header
            # p tsv._tsv_header
      end

end