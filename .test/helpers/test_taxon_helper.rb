# frozen_string_literal: true

require_relative '../test_helper'

class TestTaxonHelper < Test::Unit::TestCase

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
    end

    def test_is_extinct?
        assert_same false, TaxonHelper.is_extinct?('Diplopoda')
        assert_same false, TaxonHelper.is_extinct?('Arachnida')
        assert_same false, TaxonHelper.is_extinct?('Ostracoda')
        assert_same false, TaxonHelper.is_extinct?('Entognatha')
        assert_same false, TaxonHelper.is_extinct?('Hexanauplia')
        assert_same false, TaxonHelper.is_extinct?('Insecta')
        assert_same false, TaxonHelper.is_extinct?('Maxillopoda')
        assert_same false, TaxonHelper.is_extinct?('Chilopoda')
        assert_same false, TaxonHelper.is_extinct?('Symphyla')
        assert_same false, TaxonHelper.is_extinct?('Remipedia')
        assert_same false, TaxonHelper.is_extinct?('Pycnogonida')
        assert_same false, TaxonHelper.is_extinct?('Cephalocarida')
        assert_same false, TaxonHelper.is_extinct?('Branchiopoda')
        assert_same false, TaxonHelper.is_extinct?('Merostomata')
        assert_same false, TaxonHelper.is_extinct?('Pauropoda')
        assert_same true,  TaxonHelper.is_extinct?('Trilobita')
        assert_same true,  TaxonHelper.is_extinct?('Pliytosauria')
        assert_same true,  TaxonHelper.is_extinct?('Condylarthra')
        assert_same true,  TaxonHelper.is_extinct?('Edopsoidea')
        assert_same true,  TaxonHelper.is_extinct?('Hapalopteroidea')
        assert_same true,  TaxonHelper.is_extinct?('Hadentomoidea')
        assert_same true,  TaxonHelper.is_extinct?('Archaehymenoptera')
        assert_same true,  TaxonHelper.is_extinct?('Hemiodonata')
        assert_same true,  TaxonHelper.is_extinct?('Protoblattoidea')
        assert_same true,  TaxonHelper.is_extinct?('Protohemiptera')
    end

    def test_get_ncbi_records

        params = Hash.new { |h,k| h[k]= Hash.new }
        params[:taxonomy][:synonyms_allowed] =  true
        assert_nil TaxonHelper.get_ncbi_records('xxxxccccccxxxxxx', params)
        assert_equal Array, TaxonHelper.get_ncbi_records('Lentulidae', params).class
        assert_equal [@lentulidae_obj], TaxonHelper.get_ncbi_records('Lentulidae', params)
    end

    def test_choose_ncbi_record
        assert_nil TaxonHelper.choose_ncbi_record(taxon_name: 'xxxxccccccxxxxxx')
        assert_equal OpenStruct, TaxonHelper.choose_ncbi_record(taxon_name: 'Lentulidae').class
        assert_equal @lentulidae_obj, TaxonHelper.choose_ncbi_record(taxon_name: 'Lentulidae')
    end

    def test_get_taxon_record
        params = Hash.new { |h, k| h[k] = Hash.new }
        params[:taxon] = 'Lentulidae'
        params[:taxonomy][:ncbi] = true
        params[:taxonomy][:gbif] = false
        params[:taxonomy][:gbif_backbone] = false

        assert_equal OpenStruct, TaxonHelper.get_taxon_record(params).class      
        assert_equal @lentulidae_obj, TaxonHelper.get_taxon_record(params)          
        
        params[:taxon] = 'xxxxccccccxxxxxx'
        assert_equal nil, TaxonHelper.get_taxon_record(params)          
        
        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = true
        params[:taxonomy][:gbif_backbone] = false
        assert_equal nil, TaxonHelper.get_taxon_record(params)          

        params[:taxon] = 'Lentulidae'
        assert_equal GbifTaxonomy, TaxonHelper.get_taxon_record(params).class
        
        obj = GbifTaxonomy.find_by(canonical_name: 'Lentulidae')
        assert_equal obj, TaxonHelper.get_taxon_record(params)
        
        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = false
        params[:taxonomy][:gbif_backbone] = true
        params[:taxon] = 'xxxxccccccxxxxxx'
        assert_equal nil, TaxonHelper.get_taxon_record(params)          
        
        params[:taxon] = 'Lentulidae'
        assert_equal GbifTaxonomy, TaxonHelper.get_taxon_record(params).class
        assert_equal obj, TaxonHelper.get_taxon_record(params)
    end


    def test_assign_taxon_info_to_params
        params = Hash.new { |h, k| h[k] = Hash.new }

        params[:taxon] = 'Lentulidae'
        params[:taxonomy][:ncbi] = true
        params[:taxonomy][:gbif] = false
        params[:taxonomy][:gbif_backbone] = false
        obj = GbifTaxonomy.find_by(canonical_name: 'Lentulidae')

        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')
        
        params[:taxon_object] = @lentulidae_obj
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')


        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = true
        params[:taxonomy][:gbif_backbone] = false
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')

        params[:taxon_object] = obj
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')
        
        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = false
        params[:taxonomy][:gbif_backbone] = true
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')

        params[:taxon_object] = obj
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')


        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = false
        params[:taxonomy][:gbif_backbone] = false
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')

        params[:taxon_object] = @lentulidae_obj ## defaults to ncbi
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')


        params[:taxonomy][:ncbi] = true
        params[:taxonomy][:gbif] = false
        params[:taxonomy][:gbif_backbone] = false
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_raise (SystemExit) { TaxonHelper.assign_taxon_info_to_params(params.dup, 'xxxxccccxxxxx') }
        assert_nothing_raised (SystemExit) { TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae') }
    end
end