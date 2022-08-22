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


        # #<NcbiName id: 105810, tax_id: 62781, name: "Lentulidae", unique_name: "", name_class: "scientific name", created_at: "2022-02-15 18:32:25", updated_at: "2022-02-15 18:32:25">
        NcbiName.create!(
            tax_id: 62781,
            name: 'Lentulidae',
            unique_name: '', 
            name_class: 'scientific name'
        )


        # #<NcbiRankedLineage id: 1742226, tax_id: 62781, name: "Lentulidae", species: "", genus: "", familia: "", ordo: "Orthoptera", classis: "Insecta", phylum: "Arthropoda", regnum: "Metazoa", super_regnum: "Eukaryota", created_at: "2022-02-15 18:58:15", updated_at: "2022-02-15 18:58:15">
        NcbiRankedLineage.create!(
            tax_id: 62781,
            name: "Lentulidae",
            species: "",
            genus: "",
            familia: "",
            ordo: "Orthoptera",
            classis: "Insecta",
            phylum: "Arthropoda",
            regnum: "Metazoa",
            super_regnum: "Eukaryota"
        )


        # #<NcbiNode id: 40907, tax_id: 62781, parent_tax_id: 92621, rank: "family", division_id: 1, genetic_code_id: 1, mito_genetic_code_id: 5, has_specified_species: false, plastid_genetic_code_id: 0, created_at: "2022-02-15 19:02:08", updated_at: "2022-02-15 19:02:08">
        NcbiNode.create!(
            tax_id: 62781,
            parent_tax_id: 92621,
            rank: "family",
            division_id: 1,
            genetic_code_id: 1,
            mito_genetic_code_id: 5,
            has_specified_species: false,
            plastid_genetic_code_id: 0
        )


        # #<GbifTaxonomy id: 336438, taxon_id: 7254, dataset_id: "7ddf754f-d193-4cc9-b351-99906754a03b", parent_name_usage_id: "1458", accepted_name_usage_id: nil, original_name_usage_id: nil, scientific_name: "Lentulidae", scientific_name_authorship: nil, canonical_name: "Lentulidae", generic_name: "Lentulidae", specific_epithet: nil, infraspecific_epithet: nil, taxon_rank: "family", name_according_to: nil, name_published_in: "Dirsh, V.M. (1956) The phallic complex in Acridoid...", taxonomic_status: "accepted", nomenclatural_status: nil, taxon_remarks: nil, regnum: "Animalia", phylum: "Arthropoda", classis: "Insecta", ordo: "Orthoptera", familia: "Lentulidae", genus: nil, created_at: "2022-02-15 15:39:21", updated_at: "2022-02-15 15:39:21">]
        GbifTaxonomy.create!(
            taxon_id: 7254,
            dataset_id: "7ddf754f-d193-4cc9-b351-99906754a03b",
            parent_name_usage_id: "1458",
            accepted_name_usage_id: nil,
            original_name_usage_id: nil,
            scientific_name: "Lentulidae",
            scientific_name_authorship: nil,
            canonical_name: "Lentulidae",
            generic_name: "Lentulidae",
            specific_epithet: nil,
            infraspecific_epithet: nil,
            taxon_rank: "family",
            name_according_to: nil,
            name_published_in: "Dirsh, V.M. (1956) The phallic complex in Acridoid...",
            taxonomic_status: "accepted",
            nomenclatural_status: nil,
            taxon_remarks: nil,
            regnum: "Animalia",
            phylum: "Arthropoda",
            classis: "Insecta",
            ordo: "Orthoptera",
            familia: "Lentulidae",
            genus: nil
        )


        @params = {taxon_object: @lentulidae_obj, taxonomy: { ncbi: true}}
        @params2 = {taxon_object: @metazoa_obj, taxonomy: { ncbi: true}}
        @params3 = {taxon_object: nil, taxonomy: { ncbi: true}}
    end


    def teardown
        NcbiName.delete_all
        NcbiNode.delete_all
        NcbiRankedLineage.delete_all
        GbifTaxonomy.delete_all
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
        # assert_equal [1], NcbiDivision.get_division_id_by_taxon_name('Hymenoptera')
        # assert_equal [1], NcbiDivision.get_division_id_by_taxon_name('Bombus')
        assert_equal [1], NcbiDivision.get_division_id_by_taxon_name('Lentulidae')
        # assert_equal [5], NcbiDivision.get_division_id_by_taxon_name('Pan troglodytes')
        # assert_equal [2], NcbiDivision.get_division_id_by_taxon_name('Soricidae')
        # assert_equal [6], NcbiDivision.get_division_id_by_taxon_name('Mus musculus')
        # assert_equal [4], NcbiDivision.get_division_id_by_taxon_name('Quercus')
    end

    def test_codes_for_taxon
        assert_equal ['inv'], NcbiDivision.codes_for_taxon(@params)
        assert_equal ["inv", "mam", "pri", "rod", "vrt"], NcbiDivision.codes_for_taxon(@params2)
        assert_nil NcbiDivision.codes_for_taxon(@params3)
    end
end