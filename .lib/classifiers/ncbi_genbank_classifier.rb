# frozen_string_literal: true

class NcbiGenbankClassifier
    include StringFormatting
    include GeoUtils

    attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :markers, :fast_run, :regexes_for_markers, :file_manager, :filter_params, :taxonomy_params, :region_params, :params

    FILE_DESCRIPTION_PART = 10

    def _possible_taxa
        ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
    end

    def initialize(params:, file_name:, file_manager:)
        @file_name            = file_name
        @params               = params
        @query_taxon_object   = params[:taxon_object]
        @query_taxon_name     = query_taxon_object.canonical_name
        @query_taxon_rank     = query_taxon_object.taxon_rank
        @markers              = params[:marker_objects]
        @fast_run             = params[:fast_run]
        @regexes_for_markers  = Marker.regexes(db: self.class, markers: markers)
        @file_manager         = file_manager
        @filter_params        = params[:filter]
        @taxonomy_params      = params[:taxonomy]
        @region_params        = params[:region]
    end

    def run
        
        file_names = []
        file_names.push(file_name)
        erroneous_files = []


        file_names.each do |file|
            file_name_match             = file.to_s.match(/gb\w+\d+/)
            base_name                   = file_name_match[0]
            specimens_of_taxon          = Hash.new { |hash, key| hash[key] = {} }
            specimens_of_sequence       = Hash.new


            puts "Worker #{Parallel.worker_number} parsing:\t'#{file_name}'"
            file_of = MiscHelper.create_output_files(file_manager: file_manager, query_taxon_name: query_taxon_name, file_name: file_name, params: params, source_db: 'ncbi') unless DerepHelper.do_derep
            begin
                Zlib::GzipReader.open(file) do |gz_file|
                    ff = Bio::FlatFile.new(Bio::GenBank, gz_file)                    
                    ff.each_entry do |gb|
                        _matches_query_taxon(gb) ? nil : next if fast_run

                        features_of_gene  = gb.features.select { |f| _is_gene_feature?(f.feature) && _is_gene_of_marker?(f.qualifiers) && _is_no_pseudogene?(f.qualifiers) }
                        next unless features_of_gene.size == 1 ## TODO: why 1 ?
                        
                        nucs = gb.naseq.splicing(features_of_gene.first.position).to_s
                        next if nucs.nil? || nucs.empty?

                        nucs = FilterHelper.filter_seq(nucs, filter_params)
                        next if nucs.nil? || nucs.empty?

                        nucs.upcase!

                        specimen = _get_specimen(gb: gb, nucs: nucs)

                        next unless specimen_is_from_area(specimen: specimen, region_params: region_params) if region_params.any?
                        
                        SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
                    end
                end
            rescue Zlib::Error => e
                puts file
                p e
                erroneous_files.push(file)
            end
            puts "Worker #{Parallel.worker_number} classifying:\t'#{file_name}'"


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


            if DerepHelper.do_derep
                puts "Starting dereplication for file #{file_name}"
                
                DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params, query_taxon_name, 'ncbi')
                
                ## TODO: do I need this? Or do I close neded files?
                # file_of.each { |fc, fh| fh.close }

                
                puts 'dereplication finished'
                puts
            else
                ## TODO: Check if it should also be done for Comparison
                OutputFormat::Tsv.rewind
                file_of.each { |fc, fh| fh.close }
            end

        end

        
        return erroneous_files
    end

    def self.get_taxon_object_for_unmapped(first_specimen)
        ncbi_ranked_lineage = NcbiGenbankClassifier.get_ncbi_ranked_lineage(first_specimen)
        return nil if ncbi_ranked_lineage.nil?

        regnum          = ncbi_ranked_lineage.regnum
        phylum          = ncbi_ranked_lineage.phylum
        classis         = ncbi_ranked_lineage.classis
        ordo            = ncbi_ranked_lineage.ordo
        familia         = ncbi_ranked_lineage.familia
        genus           = ncbi_ranked_lineage.genus
        species         = ncbi_ranked_lineage.species
        canonical_name  = ncbi_ranked_lineage.name

        ncbi_node = NcbiNode.find_by(tax_id: ncbi_ranked_lineage.tax_id)
        return nil if ncbi_node.nil?

        taxon_rank = ncbi_node.rank 
        lineage = []

        obj = OpenStruct.new(
            taxon_id:               ncbi_ranked_lineage.tax_id,
            regnum:                 regnum,
            phylum:                 phylum,
            classis:                classis,
            ordo:                   ordo,
            familia:                familia,
            genus:                  genus,
            canonical_name:         canonical_name,
            scientific_name:        'no_info',
            taxonomic_status:       'no_info',
            taxon_rank:             taxon_rank,
            combined:               lineage,
            comment:                ''
        )

        ## add missing taxa names to obj
        if GbifTaxonomy.possible_ranks.include?(ncbi_node.rank)
            latinized_rank = TaxonomyHelper.latinize_rank(ncbi_node.rank)
            obj[latinized_rank] = ncbi_ranked_lineage.name
        else
            GbifTaxonomy.possible_ranks.each do |possible_rank|
                latinized_possible_rank = TaxonomyHelper.latinize_rank(possible_rank)
                if latinized_possible_rank == 'canonical_name'
                    name_for_possible_rank  = ncbi_ranked_lineage.public_send('species').to_s
                else
                    name_for_possible_rank  = ncbi_ranked_lineage.public_send(latinized_possible_rank).to_s
                end

                next if name_for_possible_rank.empty?
                
                obj[latinized_possible_rank]    = name_for_possible_rank
                obj.canonical_name              = name_for_possible_rank
            end
        end

        ## add taxa to lineage
        GbifTaxonomy.possible_ranks.each do |possible_rank|
            latinized_possible_rank = TaxonomyHelper.latinize_rank(possible_rank)
            obj.combined.push(obj[latinized_possible_rank]) unless obj[latinized_possible_rank].to_s.empty? 
        end

        return obj
    end

    def self.get_ncbi_ranked_lineage(gb)
        source_feature      = gb.features.select { |f| NcbiGenbankClassifier.is_source_feature?(f.feature) }.first
        return nil if source_feature.nil?

        taxon_db_xref       = source_feature.qualifiers.select { |q| NcbiGenbankClassifier.is_db_taxon_xref_qualifier?(q) }.first
        return nil if taxon_db_xref.nil?

        ncbi_taxon_id       = taxon_db_xref.value.gsub('taxon:', '').to_i
        return nil if ncbi_taxon_id.nil?


        ranked = NcbiRankedLineage.find_by(tax_id: ncbi_taxon_id)
        
        return ranked
    end

    def self.is_db_taxon_xref_qualifier?(qualifier)
        qualifier.qualifier == 'db_xref' && /^taxon:/ === qualifier.value
    end

    def self.is_source_feature?(s)
        s == 'source'
    end

    private
    def _is_gene_feature?(s)
        s == 'gene'
    end

    def _is_source_feature?(s)
        s == 'source'
    end

    def _get_source_features(gb)
        gb.features.select { |f| _is_source_feature?(f.feature) }
    end

    def _get_country_value(source_features)
        country = nil
        source_features.each { |f| f.qualifiers.each { |q| q.qualifier == 'country' ? country = q.value : nil } }

        country_ary = []
        country_ary = country.split(':') if country

        return country_ary
    end

    def _get_lat_lon_value(source_features)
        lat_lon = nil
        source_features.each { |f| f.qualifiers.each { |q| q.qualifier == 'lat_lon' ? lat_lon = q.value : nil } }

        lat_lon_ary = []
        if lat_lon
            lat_lon_ary = lat_lon.split(' ')
            lat = lat_lon_ary[1] == 'N' ? lat_lon_ary[0] : "-#{lat_lon_ary[0]}"
            lon = lat_lon_ary[3] == 'E' ? lat_lon_ary[2] : "-#{lat_lon_ary[2]}"
            lat_lon_ary = [lat, lon]
        end
        
        return lat_lon_ary
    end

    def _is_gene_of_marker?(qualifiers)
        qualifiers.any? { |q| q.qualifier == 'gene' && regexes_for_markers === q.value}
    end

    def _is_no_pseudogene?(qualifiers)
        qualifiers.none? { |q| q.qualifier == 'pseudo' }
    end

    def _get_specimen(gb:, nucs:)
        source_taxon_name             = gb.organism
        nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)

        source_features               = _get_source_features(gb)
        location                      = _get_country_value(source_features).first
        lat_lon                       = _get_lat_lon_value(source_features)
        lat                           = lat_lon.first
        long                          = lat_lon.last

        specimen                      = Specimen.new
        specimen.identifier           = gb.accession
        specimen.sequence             = nucs
        specimen.source_taxon_name    = source_taxon_name
        specimen.nomial               = nomial
        specimen.taxon_name           = nomial.name
        specimen.location             = location
        specimen.lat                  = lat
        specimen.long                 = long
        specimen.first_specimen_info  = gb

        return specimen
    end

    def self.get_source_lineage(gb)
        OpenStruct.new(
            name: gb.organism,
            combined: gb.classification
        )
    end

    def _matches_query_taxon(gb)
        /#{query_taxon_name}/.match?(gb.taxonomy) || /#{query_taxon_name}/.match?(gb.organism)
    end
end
