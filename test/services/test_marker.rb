# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/services/marker'

class TestMarker < Test::Unit::TestCase

      def setup
            @marker = Marker.new(query_marker_name: 'coi')
      end

      def test_marker_tag
            m1 = Marker.new(query_marker_name: 'coi')
            m2 = Marker.new(query_marker_name: 'cox1')
            m3 = Marker.new(query_marker_name: 'co1')
            m4 = Marker.new(query_marker_name: 'cytochrome1')
            m5 = Marker.new(query_marker_name: 'cytochromeone')

            assert_equal :co1, m1.marker_tag
            assert_equal :co1, m2.marker_tag
            assert_equal :co1, m3.marker_tag
            assert_equal :co1, m4.marker_tag
            assert_equal :co1, m5.marker_tag
      end

      def test_regexes
            ncbi_regexes = Marker.regexes(db: NcbiGenbankImporter, markers: [@marker])
            bold_regexes = Marker.regexes(db: BoldImporter, markers: [@marker])
            gbol_regexes = Marker.regexes(db: GbolImporter, markers: [@marker])

            assert_match ncbi_regexes, 'cytochrome oxidase 1'
            assert_match bold_regexes, 'COI-5P'
            assert_match gbol_regexes, 'Whatever'
      end

      ## Good tests for search_terms_of?
end