# frozen_string_literal: true

require_relative '../test_helper'

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
            
            assert_raise (SystemExit) { Marker.new(query_marker_name: nil) }
            assert_raise (SystemExit) { Marker.new(query_marker_name: 'whatever') }
      end

      def test_regexes
            ncbi_regexes = Marker.regexes(db: NcbiGenbankImporter, markers: [@marker])
            bold_regexes = Marker.regexes(db: BoldImporter, markers: [@marker])
            gbol_regexes = Marker.regexes(db: GbolImporter, markers: [@marker])

            assert_match ncbi_regexes, 'cytochrome oxidase 1'
            assert_match bold_regexes, 'COI-5P'
            assert_match gbol_regexes, 'Whatever'
      end

      def test_searchterms_of
            assert_equal ['^cox1$','^co1$', '^coi$', '^cytochrome1$', '^cytochromeone$'], Marker.searchterms_of[@marker.marker_tag][:all]
            assert_equal ['^cox1$', '^co1$', '^coi$', '^cytochrome oxidase 1$', '^cytochrome oxidase I$', '^cytochrome oxidase one$', '^cytochrome oxidase subunit 1$', '^cytochrome oxidase subunit I$', '^cytochrome oxidase subunit one$'], Marker.searchterms_of[@marker.marker_tag][:ncbi]
            assert_equal ['.*'], Marker.searchterms_of[@marker.marker_tag][:gbol]
            assert_equal ['COI-5P'], Marker.searchterms_of[@marker.marker_tag][:bold]
      end

      def test_regex
            assert_equal /^cox1$|^co1$|^coi$|^cytochrome oxidase 1$|^cytochrome oxidase I$|^cytochrome oxidase one$|^cytochrome oxidase subunit 1$|^cytochrome oxidase subunit I$|^cytochrome oxidase subunit one$/i, @marker.regex(db: NcbiGenbankImporter)
            assert_equal /^cox1$|^co1$|^coi$|^cytochrome oxidase 1$|^cytochrome oxidase I$|^cytochrome oxidase one$|^cytochrome oxidase subunit 1$|^cytochrome oxidase subunit I$|^cytochrome oxidase subunit one$/i, @marker.regex(db: NcbiGenbankJob)
            assert_equal /^cox1$|^co1$|^coi$|^cytochrome oxidase 1$|^cytochrome oxidase I$|^cytochrome oxidase one$|^cytochrome oxidase subunit 1$|^cytochrome oxidase subunit I$|^cytochrome oxidase subunit one$/i, @marker.regex(db: NcbiGenbankConfig)
            assert_equal /^cox1$|^co1$|^coi$|^cytochrome oxidase 1$|^cytochrome oxidase I$|^cytochrome oxidase one$|^cytochrome oxidase subunit 1$|^cytochrome oxidase subunit I$|^cytochrome oxidase subunit one$/i, @marker.regex(db: NcbiApi)
            
            assert_equal /.*/i, @marker.regex(db: GbolImporter)
            assert_equal /.*/i, @marker.regex(db: GbolJob)
            assert_equal /.*/i, @marker.regex(db: GbolConfig)
            
            assert_equal /COI-5P/i, @marker.regex(db: BoldImporter)
            assert_equal /COI-5P/i, @marker.regex(db: BoldJob)
            assert_equal /COI-5P/i, @marker.regex(db: BoldConfig)
      end
end