# frozen_string_literal: true

require_relative '../test_helper'

class TestStringFormatting < Test::Unit::TestCase

      def setup
            @lineage_data = OpenStruct.new(
                  regnum: 'Animalia',
                  phylum: 'Arthropoda',
                  classis: 'Insecta',
                  ordo: 'Hymenoptera',
                  familia: 'Apidae',
                  genus: 'Apis',
                  canonical_name: 'Apis mellifera',
                  taxon_rank: 'species')
            @identifier ='Test-123'
            @sequence = 'ACGTCGCTAGTCGCTCTGATCGCTCTCGAGCTGAT'
      end

      def test__tsv_header
            assert_equal "identifier\tkingdom\tphylum\torder\tfamily\tgenus\tcanonical_name\tsequence", OutputFormat::Tsv._tsv_header
            # p tsv._tsv_header
      end

      def test__tsv_row
            lineage_data1 = @lineage_data
            
            lineage_data2 = @lineage_data.dup
            lineage_data2.canonical_name = nil
            lineage_data2.taxon_rank = 'genus'

            assert_equal "#{@identifier}\tAnimalia\tArthropoda\tInsecta\tHymenoptera\tApidae\tApis\tApis mellifera\t#{@sequence}", OutputFormat::Tsv._tsv_row(lineage_data: lineage_data1, identifier: @identifier, sequence: @sequence)
            assert_equal "#{@identifier}\tAnimalia\tArthropoda\tInsecta\tHymenoptera\tApidae\tApis\t\t#{@sequence}", OutputFormat::Tsv._tsv_row(lineage_data: lineage_data2, identifier: @identifier, sequence: @sequence)
      end

      def test__fasta_header
            data = [@identifier, @sequence]
            lineage_data2 = @lineage_data.dup
            lineage_data2.canonical_name = nil
            lineage_data2.taxon_rank = 'genus'

            assert_equal ">#{@identifier}|Animalia|Arthropoda|Insecta|Hymenoptera|Apidae|Apis mellifera", OutputFormat::Fasta._fasta_header(data: data, taxonomic_info: @lineage_data)
            assert_equal ">#{@identifier}|Animalia|Arthropoda|Insecta|Hymenoptera|Apidae|Apis", OutputFormat::Fasta._fasta_header(data: data, taxonomic_info: lineage_data2)
      end
end