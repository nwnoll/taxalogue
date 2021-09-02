# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiDivision < Test::Unit::TestCase

    def setup
        @lentulidae_obj = OpenStruct.new(
            taxon_id: 62781,
            regnum: 'Metazoa',
            phylum: 'Arthropoda',
            classis: 'Insecta',
            ordo: 'Orthoptera',
            familia: 'Lentulidae',
            genus: '',
            canonical_name: 'Lentulidae',
            scientific_name: 'Lentulidae',
            taxonomic_status: 'accepted',
            taxon_rank: 'family',
            comment: ''
        )

        @vertebrata_animal_obj = OpenStruct.new(
            taxon_id:7742,
            regnum:"Metazoa",
            phylum:"Chordata",
            classis:"",
            ordo:"",
            familia:"",
            genus:"",
            canonical_name:"Vertebrata",
            scientific_name:"Vertebrata Cuvier, 1812",
            taxonomic_status:"accepted",
            taxon_rank:"clade",
            comment:""
        )

        @metazoa_obj = OpenStruct.new(
            taxon_id:33208,
            regnum:"Metazoa",
            phylum:"",
            classis:"",
            ordo:"",
            familia:"",
            genus:"",
            canonical_name:"Metazoa",
            scientific_name:"Metazoa",
            taxonomic_status:"accepted",
            taxon_rank:"kingdom",
            comment:""
        )


        @params = {taxon_object: @lentulidae_obj, taxonomy: { ncbi: true}}
        @params2 = {taxon_object: @metazoa_obj, taxonomy: { ncbi: true}}
        @params3 = {taxon_object: nil, taxonomy: { ncbi: true}}
    end
      
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

    def test_codes_for_taxon
        assert_equal ['inv'], NcbiDivision.codes_for_taxon(@params)
        assert_equal ["inv", "mam", "pri", "rod", "vrt"], NcbiDivision.codes_for_taxon(@params2)
        assert_nil NcbiDivision.codes_for_taxon(@params3)
    end
end