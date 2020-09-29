# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/services/marker'

class TestHelper < Test::Unit::TestCase

      def setup
      end

      def test_generate_index_by_column_name
            tempfile = Tempfile.create('test_generate_index_by_column_name')
            tempfile.write("processid\ttsampleid\ttrecordID\ttcatalognum\ttfieldnum\ttinstitution_storing\tcollection_code\tbin_uri\tphylum_taxID\tphylum_name\tclass_taxID\tclass_name\torder_taxID\torder_name\tfamily_taxID\tfamily_name\tsubfamily_taxID\tsubfamily_name\tgenus_taxID\tgenus_name\tspecies_taxID\tspecies_name\tsubspecies_taxID\tsubspecies_name\tidentification_provided_by\tidentification_method\tidentification_reference\ttax_note\tvoucher_status\ttissue_type\tcollection_event_id\tcollectors\tcollectiondate_start\tcollectiondate_end\tcollectiontime\tcollection_note\tsite_code\tsampling_protocol\tlifestage\tsex\treproduction\thabitat\tassociated_specimens\tassociated_taxa\textrainfo\tnotes\tlat\tlon\tcoord_source\tcoord_accuracy\telev\tdepth\telev_accuracy\tdepth_accuracy\tcountry\tprovince_state\tregion\tsector\texactsite\timage_ids\timage_urls\tmedia_descriptors\tcaptions\tcopyright_holders\tcopyright_years\tcopyright_licenses\tcopyright_institutions\tphotographers\tsequenceID\tmarkercode\tgenbank_accession\tnucleotides\ttrace_ids\ttrace_names\ttrace_links\trun_dates\tsequencing_centers\tdirections\tseq_primers\tmarker_codes")
            tempfile.write("\nAGMPK217-18\tBIOUG37024-D07\t8562520\tBIOUG37024-D07\tL#17AGAS4-02N\tCentre for Biodiversity Genomics\t\tBOLD:ACM9724\t20\tArthropoda\t82\tInsecta\t125\tHymenoptera\t106636\tPlatygastridae\t\t\t\t\t\t\t\t\tKate Perez\tBIN Taxonomy Match (Mar 2018)\t\t\tVouchered:Registered Collection\tinv whole voucher\t\tCBG Collections\t\t\t\t4-headed SLAM trap (N)\t\tMalaise Trap\tA\t\t\tAgricultural\t\t\tAS4\t\t43.5264\t-80.1796\tGPS\t\t329\t\t\t\tCanada\tOntario\tWellington Co.\tGuelph, Arkell Research Station\tSoy field, trap 4\t\t\t\t\t\t\t\t\t\t9858437\tCOI-5P\t\tAACTCTTTATTTCTTATTTGGAATTTGATCTGGTATAATTGGAAGAAGACTCAGTATAATTATTCGTATAGAAGTAGGAATAAGAGGAACTTTAATTGGTAATGATCAAATTTATAATTCTATTGTTACAGCTCATGCATTTATTATAATTTTTTTTATAATTATACCCCTAATATTAGGAGGATTTGGAAATTGACTAATTCCTTTAATATTATCTGCTCCAGATATAGCATTCCCCCGTATAAATAATATAAGATTTTGGCTATTACCCCCATCCCTAATACTATTAATTTATAGAAATATTTTTGGTATAGGGACTGGTACTGGATGAACATTATATCCTCCTTTATCTTTATTAACTAATCCCTCTATTGACATAAGAATCTTTTCTCTCCATTTAGCTGGTATTTCATCAATTTTAGGATCAATTAATTTTATCTGTACTATTATCAATATAACTCCCATAAATATAAAAATAGAAAAAATATCTTTATTTTCATGATCAATTTTTATTACAACAATTCTTCTTCTACTTTCCTTACCTGTATTAGCAGGGGCTATTACTATACTATTAACAGACCGAAACTTAAATACTTCTTTTTTTGATCCTTCAGGAGGAGGAGACCCTGTTCTTTATCAACACTTATTC\t\t\t\t\t\t\t\t")
            tempfile.rewind

            index_by_column_name = Helper.generate_index_by_column_name(file: tempfile, separator: "\t")
            
            specimen_data = []
            tempfile.each do |row|
                  specimen_data = row.scrub!.chomp.split("\t")
            end

            nucs  = 'AACTCTTTATTTCTTATTTGGAATTTGATCTGGTATAATTGGAAGAAGACTCAGTATAATTATTCGTATAGAAGTAGGAATAAGAGGAACTTTAATTGGTAATGATCAAATTTATAATTCTATTGTTACAGCTCATGCATTTATTATAATTTTTTTTATAATTATACCCCTAATATTAGGAGGATTTGGAAATTGACTAATTCCTTTAATATTATCTGCTCCAGATATAGCATTCCCCCGTATAAATAATATAAGATTTTGGCTATTACCCCCATCCCTAATACTATTAATTTATAGAAATATTTTTGGTATAGGGACTGGTACTGGATGAACATTATATCCTCCTTTATCTTTATTAACTAATCCCTCTATTGACATAAGAATCTTTTCTCTCCATTTAGCTGGTATTTCATCAATTTTAGGATCAATTAATTTTATCTGTACTATTATCAATATAACTCCCATAAATATAAAAATAGAAAAAATATCTTTATTTTCATGATCAATTTTTATTACAACAATTCTTCTTCTACTTTCCTTACCTGTATTAGCAGGGGCTATTACTATACTATTAACAGACCGAAACTTAAATACTTCTTTTTTTGATCCTTCAGGAGGAGGAGACCCTGTTCTTTATCAACACTTATTC'
            id    = 'AGMPK217-18'
            lat   = '43.5264'
            lon  = '-80.1796'

            assert_equal id, specimen_data[index_by_column_name['processid']]
            assert_equal nucs, specimen_data[index_by_column_name['nucleotides']]
            assert_equal lat, specimen_data[index_by_column_name['lat']]
            assert_equal lon, specimen_data[index_by_column_name['lon']]
      end

      def test_create_marker_objects
            assert_kind_of Array, Helper.create_marker_objects(query_marker_names: 'co1')
            assert_kind_of Array, Helper.create_marker_objects(query_marker_names: nil)
            assert_kind_of Array, Helper.create_marker_objects(query_marker_names: 'co1,cox1')
            assert_raise (SystemExit) { Helper.create_marker_objects(query_marker_names: 'co1, cox1') }
            assert_raise (SystemExit) { Helper.create_marker_objects(query_marker_names: 'whatever') }
      end

      def test_normalize
            assert_equal 'A', Helper.normalize('Â')
            assert_equal 'A', Helper.normalize('A')
      end


      def test_latinize_rank
            assert_equal 'regnum',  Helper.latinize_rank('kingdom')
            assert_equal 'phylum',  Helper.latinize_rank('phylum')
            assert_equal 'ordo',    Helper.latinize_rank('order')
            assert_equal 'familia', Helper.latinize_rank('family')
            assert_equal 'genus',   Helper.latinize_rank('genus')
            assert_equal 'species', Helper.latinize_rank('species')
            assert_equal nil, Helper.latinize_rank(nil)
            assert_equal nil, Helper.latinize_rank([])
            assert_equal nil, Helper.latinize_rank(['test1', 'test2'])
            assert_equal nil, Helper.latinize_rank({})
      end
     
end