# frozen_string_literal: true

class MidoriClassifier
    include StringFormatting
    include GeoUtils
    attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :taxonomy_params, :region_params, :params

    def self.get_source_lineage(header)
        lineage = MiscHelper.get_lineage_from_midori_header(header)

        OpenStruct.new(
            name:     lineage.detect { |e| !e.nil? },
            combined: lineage.reverse
        )
    end

    def self.get_taxon_object_for_unmapped(first_specimen)

        lineage = MiscHelper.get_lineage_from_midori_header(first_specimen)
        canonical_name = lineage.detect {|e| !e.nil? }
        index = lineage.index(canonical_name)
        return nil if index.nil?

        taxon_rank = GbifTaxonomy.possible_ranks[index]

        obj = OpenStruct.new(
            taxon_id:               'no_info',
            regnum:                 lineage[GbifTaxonomy::REGNUM].to_s,
            phylum:                 lineage[GbifTaxonomy::PHYLUM].to_s,
            classis:                lineage[GbifTaxonomy::CLASSIS].to_s,
            ordo:                   lineage[GbifTaxonomy::ORDO].to_s,
            familia:                lineage[GbifTaxonomy::FAMILIA].to_s,
            genus:                  lineage[GbifTaxonomy::GENUS].to_s,
            canonical_name:         canonical_name.to_s,
            scientific_name:        'no_info',
            taxonomic_status:       'no_info',
            taxon_rank:             taxon_rank,
            combined:               lineage.reverse,
            comment:                ''
        )

        return obj
    end

    def initialize(params:, file_name:, file_manager:)
        @file_name          = file_name
        @params             = params
        @query_taxon_object = params[:taxon_object]
        @query_taxon_name   = query_taxon_object.canonical_name
        @query_taxon_rank   = query_taxon_object.taxon_rank
        @fast_run           = params[:fast_run]
        @file_manager       = file_manager
        @filter_params      = params[:filter]
        @taxonomy_params    = params[:taxonomy]
        @region_params      = params[:region]
    end

    def run
        MiscHelper.OUT_header('Starting to classify MIDORI downloads')
        puts

        specimens_of_taxon = Hash.new { |hash, key| hash[key] = {} }
        begin
            Zlib::GzipReader.open(file_name) do |gz_file|
                seq_of = MiscHelper.fasta_gzip_to_hash(gz_file)

                seq_of.each do |header, nucs|
                    _matches_query_taxon(header) ? nil : next if fast_run
                    
                    next if nucs.nil? || nucs.empty?

                    nucs = FilterHelper.filter_seq(nucs, filter_params)
                    next if nucs.nil? || nucs.empty?

                    nucs.upcase!
                    specimen = _get_specimen(header: header, nucs: nucs)

                    
                    SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
                end
            end
        rescue Zlib::Error => e
            puts file
            p e
            erroneous_files.push(file)
        end

        specimens_of_sequence = Hash.new
        file_of = MiscHelper.create_output_files(file_manager: file_manager, query_taxon_name: query_taxon_name, file_name: file_name, params: params, source_db: 'midori') unless DerepHelper.do_derep

        puts 'Starting taxa search'

        specimens_of_taxon.keys.each do |taxon_name|
            nomial              = specimens_of_taxon[taxon_name][:nomial]
            next unless nomial

            first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]

            taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)
            
            next unless taxonomic_info
            next unless taxonomic_info.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name

            if filter_params[:taxon_rank]
                has_user_taxon_rank = FilterHelper.has_taxon_rank(rank: filter_params[:taxon_rank], taxonomic_info: taxonomic_info)
                
                next unless has_user_taxon_rank
            end

            if DerepHelper.do_derep
                DerepHelper.fill_specimens_of_sequence(specimens: specimens_of_taxon[taxon_name][:data], specimens_of_sequence: specimens_of_sequence, taxonomic_info: taxonomic_info, taxon_name: taxon_name, first_specimen_info: first_specimen_info)
            else
                MiscHelper.write_to_files(file_of: file_of, taxonomic_info: taxonomic_info, nomial: nomial, params: params, data: specimens_of_taxon[taxon_name][:data])
            end
        end

        puts 'taxon search completed'
        puts

        if DerepHelper.do_derep
            puts "Starting dereplication for file #{file_name}"
            
            DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params, query_taxon_name, 'midori')
            
            puts 'dereplication finished'
            puts
        else
            ## TODO: Check if it should also be done for Comparison
            OutputFormat::Tsv.rewind
            file_of.each { |fc, fh| fh.close }
        end

        return nil
    end
  
    private
    #    >AB843255.1.<1.>659 root_1;norank_cellular_organisms_131567;superkingdom_Eukaryota_2759;clade_Opisthokonta_33154;kingdom_Metazoa_33208;clade_Eumetazoa_6072;clade_Bilateria_33213;clade_Deuterostomia_33511;phylum_Chordata_7711;subphylum_Craniata_89593;clade_Vertebrata_7742;clade_Gnathostomata_7776;clade_Teleostomi_117570;clade_Euteleostomi_117571;superclass_Sarcopterygii_8287;clade_Dipnotetrapodomorpha_1338369;clade_Tetrapoda_32523;clade_Amniota_32524;clade_Sauropsida_8457;clade_Sauria_32561;clade_Archelosauria_1329799;clade_Archosauria_8492;clade_Dinosauria_436486;clade_Saurischia_436489;clade_Theropoda_436491;clade_Coelurosauria_436492;class_Aves_8782;infraclass_Neognathae_8825;order_Passeriformes_9126;family_Turdidae_9183;genus_Turdus_9186;species_Turdus chrysolaus_36280

    def _get_specimen(header:, nucs:)
        lineage                       = MiscHelper.get_lineage_from_midori_header(header)
        source_taxon_name             = lineage.detect { |e| !e.nil? }
        header =~ /^>(.*?)\./
        identifier                    = $1

        sequence                      = FilterHelper.filter_seq(nucs, filter_params)
        return nil if sequence.nil?

        nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)

        specimen                      = Specimen.new
        specimen.identifier           = $1
        specimen.sequence             = sequence
        specimen.source_taxon_name    = source_taxon_name
        specimen.taxon_name           = nomial.name
        specimen.nomial               = nomial
        specimen.location             = nil
        specimen.lat                  = nil
        specimen.long                 = nil
        specimen.first_specimen_info  = header
        
        return specimen
    end

    def _matches_query_taxon(header)
          return true if header.match?(query_taxon_name.gsub(' ', '_'))
    end
end
