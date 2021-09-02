# frozen_string_literal: true

require_relative '../test_helper'

class TestFilterHelper < Test::Unit::TestCase
    def test_filter_seq
        seq1 = 'ACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAT'
        seq2 = 'ACXGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAT'
        seq3 = '-----ACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAT'
        seq4 = 'NNNNNACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAT-------'
        seq5 = 'NNNNNACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGATNNNNNNN'
        seq6 = '-N-N-ACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAT-------'
        seq7 = '-----NNNNNNNNNNNNNNNNNTCGCTCGGATATAGAGATAGAT-------'
        seq8 = '-----NNNNNNNNNNNNNNNNNACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAT-------'
        seq9 = 'ACGGGGCTCGCGCGCGCTCGCTCGGATATAGAGATAGAI'
        seq10 = 'ACGGGGCTCGCGCGCGCTCGCTCGGATATA'
        seq11 = 'A' * 100
        seq12 = 'A' * 101
        seq13 = '-' * 50
        seq14 = 'N' * 50
        seq15 = 'ACGGGGCTCGCGCGCGCTCGNTCGGATATAGAGATAGAT'

        criteria1 = { max_N: 0, max_G: 0, min_length: 39, max_length: 100 }
        
        assert_equal seq1, FilterHelper.filter_seq(seq1, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq2, criteria1)
        assert_equal seq1, FilterHelper.filter_seq(seq3, criteria1)
        assert_equal seq1, FilterHelper.filter_seq(seq4, criteria1)
        assert_equal seq1, FilterHelper.filter_seq(seq5, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq7, criteria1)
        assert_equal seq1, FilterHelper.filter_seq(seq8, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq9, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq10, criteria1)
        assert_equal seq11, FilterHelper.filter_seq(seq11, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq12, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq13, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq14, criteria1)
        assert_equal nil, FilterHelper.filter_seq(seq15, criteria1)
        assert_equal seq1, FilterHelper.filter_seq(seq1, nil)
        assert_equal nil, FilterHelper.filter_seq(seq2, nil)
        assert_equal seq1, FilterHelper.filter_seq(seq3, nil)
        assert_equal seq1, FilterHelper.filter_seq(seq4, nil)
        assert_equal seq1, FilterHelper.filter_seq(seq5, nil)
        assert_equal seq1, FilterHelper.filter_seq(seq6, nil)
        assert_equal 'TCGCTCGGATATAGAGATAGAT', FilterHelper.filter_seq(seq7, nil)
        assert_equal seq12, FilterHelper.filter_seq(seq12, nil)

        seq1 = 'ACGTACGTACGT'
        seq2 = '--GTACGTACGT'
        seq3 = 'ACGTACGTAC--'
        seq4 = 'N-GTACGTACGT'
        seq5 = 'ACGTACGTACN-'
        seq6 = '-CGTACGTACGN'
        seq7 = '--GTACGTAC--'
        seq8 = 'AAAA---CGTAC'
        seq9 = 'AAAA-A-CGTAC'
        seq10 = 'ANNNNNNNNNNA'
        seq11 = 'ANNNNNNNNNNNA'
        seq12 = 'A' * 21

        criteria2 = { max_N: 10, max_G: 2, min_length: 10, max_length: 20 }

        assert_equal seq1, FilterHelper.filter_seq(seq1, criteria2)
        assert_equal 'GTACGTACGT', FilterHelper.filter_seq(seq2, criteria2)
        assert_equal 'ACGTACGTAC', FilterHelper.filter_seq(seq3, criteria2)
        assert_equal 'GTACGTACGT', FilterHelper.filter_seq(seq4, criteria2)
        assert_equal 'ACGTACGTAC', FilterHelper.filter_seq(seq5, criteria2)
        assert_equal 'CGTACGTACG', FilterHelper.filter_seq(seq6, criteria2)
        assert_equal nil, FilterHelper.filter_seq(seq7, criteria2)
        assert_equal nil, FilterHelper.filter_seq(seq8, criteria2)
        assert_equal 'AAAA-A-CGTAC', FilterHelper.filter_seq(seq9, criteria2)
        assert_equal 'ANNNNNNNNNNA', FilterHelper.filter_seq(seq10, criteria2)
        assert_equal nil, FilterHelper.filter_seq(seq11, criteria2)
        assert_equal nil, FilterHelper.filter_seq(seq12, criteria2)
    end
end