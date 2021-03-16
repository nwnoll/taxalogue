# frozen_string_literal: true

require_relative '../test_helper'

class TestHelper < Test::Unit::TestCase

      def test_constantize
            assert_same BoldConfig,                   Helper.constantize('BoldConfig')
            assert_same GbifTaxonomyConfig,           Helper.constantize('GbifTaxonomyConfig')
            assert_same GbolConfig,                   Helper.constantize('GbolConfig')
            assert_same NcbiGenbankConfig,            Helper.constantize('NcbiGenbankConfig')
            assert_same NcbiTaxonomyConfig,           Helper.constantize('NcbiTaxonomyConfig')
            assert_same Printing,                     Helper.constantize('Printing')
            assert_same FtpDownloader,                Helper.constantize('FtpDownloader')
            assert_same HttpDownloader,               Helper.constantize('HttpDownloader')
            assert_same Helper,                       Helper.constantize('Helper')
            assert_same BoldImporter,                 Helper.constantize('BoldImporter')
            assert_same GbifTaxonomyImporter,         Helper.constantize('GbifTaxonomyImporter')
            assert_same GbolImporter,                 Helper.constantize('GbolImporter')
            assert_same NcbiGenbankImporter,          Helper.constantize('NcbiGenbankImporter')
            assert_same NcbiNameImporter,             Helper.constantize('NcbiNameImporter')
            assert_same NcbiNodeImporter,             Helper.constantize('NcbiNodeImporter')
            assert_same NcbiRankedLineageImporter,    Helper.constantize('NcbiRankedLineageImporter')
            assert_same BoldJob,                      Helper.constantize('BoldJob')
            assert_same GbifTaxonomyJob,              Helper.constantize('GbifTaxonomyJob')
            assert_same NcbiGenbankJob,               Helper.constantize('NcbiGenbankJob')
            assert_same NcbiTaxonomyJob,              Helper.constantize('NcbiTaxonomyJob')
            assert_same GbifTaxonomy,                 Helper.constantize('GbifTaxonomy')
            assert_same NcbiName,                     Helper.constantize('NcbiName')
            assert_same NcbiNode,                     Helper.constantize('NcbiNode')
            assert_same NcbiRankedLineage,            Helper.constantize('NcbiRankedLineage')
            assert_same OutputFormat::Fasta,          Helper.constantize('OutputFormat::Fasta')
            assert_same OutputFormat,                 Helper.constantize('OutputFormat')
            assert_same OutputFormat::Tsv,            Helper.constantize('OutputFormat::Tsv')
            assert_same FileStructure,                Helper.constantize('FileStructure')
            assert_same GbifApi,                      Helper.constantize('GbifApi')
            assert_same Marker,                       Helper.constantize('Marker')
            assert_same NcbiApi,                      Helper.constantize('NcbiApi')
            assert_same NcbiDivision,                 Helper.constantize('NcbiDivision')
            assert_same Nomial,                       Helper.constantize('Nomial')
            assert_same Specimen,                     Helper.constantize('Specimen')
            assert_same SpecimensOfTaxon,             Helper.constantize('SpecimensOfTaxon')
            assert_same StringFormatting,             Helper.constantize('StringFormatting')
            assert_same TaxonSearch,                  Helper.constantize('TaxonSearch')
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

      def test_extract_zip
            tmp_dir     = Dir.mktmpdir
            destination = File.join(tmp_dir, 'out')
            test_name   = 'test_extract_zip'

            data = [0, 1, 2, 3, 4]
          
            zip_path = File.join(tmp_dir, "#{test_name}.zip")
          
            Zip::OutputStream.open(zip_path) do |io|
                  data.each do |d|
                        io.put_next_entry("#{test_name}#{d}.txt")
                        io.write "#{test_name}#{d}"
                  end
            end

            Helper.extract_zip(name: zip_path, destination: destination, files_to_extract: ['test_extract_zip0.txt', 'test_extract_zip1.txt'])

            assert_path_exist destination

            destination = Pathname.new(destination)
            files = destination.glob('*').select { |entry| entry.file? }
            
            assert_equal 2, files.size

            files.sort.each_with_index do |file, index|
                  assert_path_exist file
                  assert_equal "#{test_name}#{index}", File.open(file).read
            end
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