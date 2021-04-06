# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiDivision < Test::Unit::TestCase
      
      def test_code_for
            assert_equal 'bct', NcbiDivision.code_for[0]
            assert_equal 'inv', NcbiDivision.code_for[1]
            assert_equal 'mam', NcbiDivision.code_for[2]
            assert_equal 'phg', NcbiDivision.code_for[3]
            assert_equal 'pln', NcbiDivision.code_for[4]
            assert_equal 'pri', NcbiDivision.code_for[5]
            assert_equal 'rod', NcbiDivision.code_for[6]
            assert_equal 'syn', NcbiDivision.code_for[7]
            assert_equal 'una', NcbiDivision.code_for[8]
            assert_equal 'vrl', NcbiDivision.code_for[9]
            assert_equal 'vrt', NcbiDivision.code_for[10]
            assert_equal 'env', NcbiDivision.code_for[11]
            assert_nil NcbiDivision.code_for[nil]
      end

      def test_get_division_id_by_taxon_name
            assert_equal [1], NcbiDivision.get_division_id_by_taxon_name('Hymenoptera')
            assert_equal [1], NcbiDivision.get_division_id_by_taxon_name('Bombus')
            assert_equal [1], NcbiDivision.get_division_id_by_taxon_name('Lentulidae')
            assert_equal [5], NcbiDivision.get_division_id_by_taxon_name('Pan troglodytes')
            assert_equal [2], NcbiDivision.get_division_id_by_taxon_name('Soricidae')
            assert_equal [6], NcbiDivision.get_division_id_by_taxon_name('Mus musculus')
            assert_equal [4], NcbiDivision.get_division_id_by_taxon_name('Quercus')
      end
end