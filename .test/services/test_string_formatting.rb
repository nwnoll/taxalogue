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
            taxon_rank: 'species'
        )

        @data = { 
            identifier: 'Test-123',
            sequence: 'ACGTCGCTAGTCGCTCTGATCGCTCTCGAGCTGAT',
            loc: 'Germany',
            lat: '51.0',
            long: '9.0'
        }
    end

    def test__tsv_header
        assert_equal "identifier\tkingdom\tphylum\tclass\torder\tfamily\tcanonical_name\tlocation\tlatitude\tlongitude\tsequence", OutputFormat::Tsv._tsv_header
        # p tsv._tsv_header
    end

    def test__tsv_row
        lineage_data1 = @lineage_data
        
        lineage_data2 = @lineage_data.dup
        lineage_data2.canonical_name = 'Apis'
        lineage_data2.taxon_rank = 'genus'

        assert_equal "#{@data[:identifier]}\tAnimalia\tArthropoda\tInsecta\tHymenoptera\tApidae\tApis mellifera\tGermany\t51.0\t9.0\t#{@data[:sequence]}", OutputFormat::Tsv._tsv_row(lineage_data: lineage_data1, identifier: @data[:identifier], sequence: @data[:sequence], loc: @data[:loc], lat: @data[:lat], long: @data[:long])
        assert_equal "#{@data[:identifier]}\tAnimalia\tArthropoda\tInsecta\tHymenoptera\tApidae\tApis\tGermany\t51.0\t9.0\t#{@data[:sequence]}", OutputFormat::Tsv._tsv_row(lineage_data: lineage_data2, identifier: @data[:identifier], sequence: @data[:sequence], loc: @data[:loc], lat: @data[:lat], long: @data[:long])
    end

    def test__fasta_header
        lineage_data2 = @lineage_data.dup
        lineage_data2.canonical_name = 'Apis'
        lineage_data2.taxon_rank = 'genus'

        assert_equal ">#{@data[:identifier]}|Animalia|Arthropoda|Insecta|Hymenoptera|Apidae|Apis mellifera", OutputFormat::Fasta._fasta_header(data: @data, taxonomic_info: @lineage_data)
        assert_equal ">#{@data[:identifier]}|Animalia|Arthropoda|Insecta|Hymenoptera|Apidae|Apis", OutputFormat::Fasta._fasta_header(data: @data, taxonomic_info: lineage_data2)
    end

    def test__fasta_header_sintax
        lineage_data2 = @lineage_data.dup
        lineage_data2.canonical_name = 'Apis'
        lineage_data2.taxon_rank = 'genus'

        assert_equal ">#{@data[:identifier]};tax=k:Animalia,p:Arthropoda,c:Insecta,o:Hymenoptera,f:Apidae,g:Apis,s:Apis mellifera;", OutputFormat::SintaxFasta._fasta_header_sintax(data: @data, taxonomic_info: @lineage_data)
        assert_equal ">#{@data[:identifier]};tax=k:Animalia,p:Arthropoda,c:Insecta,o:Hymenoptera,f:Apidae,g:Apis;", OutputFormat::SintaxFasta._fasta_header_sintax(data: @data, taxonomic_info: lineage_data2)
    end
end