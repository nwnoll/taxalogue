# frozen_string_literal: true

class NcbiGenbankImporter
    include StringFormatting
    include GeoUtils

    attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name, :markers, :fast_run, :regexes_for_markers, :file_manager, :filter_params, :taxonomy_params, :region_params

    FILE_DESCRIPTION_PART = 10

    def _possible_taxa
        ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
    end

    def initialize(file_name:, query_taxon_object:, markers:, fast_run: true, file_manager:, filter_params: nil, taxonomy_params:, region_params:)
        @file_name            = file_name
        @query_taxon_object   = query_taxon_object
        @query_taxon_name     = query_taxon_object.canonical_name
        @query_taxon_rank     = query_taxon_object.taxon_rank
        @markers              = markers
        @fast_run             = fast_run
        @regexes_for_markers  = Marker.regexes(db: self.class, markers: markers)
        @file_manager         = file_manager
        @filter_params        = filter_params
        @taxonomy_params      = taxonomy_params
        @region_params        = region_params
    end

    def run
        file_names = []
        file_names.push(file_name)

        erroneous_files = []

        file_names.each do |file|
            file_name_match             = file.to_s.match(/gb\w+\d+/)
            base_name                   = file_name_match[0]
            specimens_of_taxon          = Hash.new { |hash, key| hash[key] = {} }
            
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
                erroneous_files.push(file)
                
                return erroneous_files
            end

            tsv             = file_manager.create_file("#{query_taxon_name}_#{file_name.basename.sub(/\..*/, '')}_ncbi_fast_#{fast_run}_output.tsv", OutputFormat::Tsv)
            fasta           = file_manager.create_file("#{query_taxon_name}_#{file_name.basename.sub(/\..*/, '')}_ncbi_fast_#{fast_run}_output.fas", OutputFormat::Fasta)
            comparison_file = file_manager.create_file("#{query_taxon_name}_#{file_name.basename.sub(/\..*/, '')}_ncbi_fast_#{fast_run}_comparison.tsv", OutputFormat::Comparison)
    
            specimens_of_taxon.keys.each do |taxon_name|
                nomial              = specimens_of_taxon[taxon_name][:nomial]
                next unless nomial

                first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
                taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)

                next unless taxonomic_info
                next unless taxonomic_info.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name

                # Synonym List
                syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [TaxonomyHelper.latinize_rank(taxonomy_params)])
                # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms: syn.synonyms)

                OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms: syn.synonyms[TaxonomyHelper.latinize_rank(taxonomy_params)], used_taxonomy: TaxonomyHelper.latinize_rank(taxonomy_params) )

                specimens_of_taxon[taxon_name][:data].each do |data|
                    OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
                    OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
                end
            end

            OutputFormat::Tsv.rewind

            tsv.close
            fasta.close
            comparison_file.close
        end

        return erroneous_files
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

    def self._is_db_taxon_xref_qualifier?(qualifier)
        qualifier.qualifier == 'db_xref' && /^taxon:/ === qualifier.value
    end

    def _get_ncbi_ranked_lineage(gb)
        source_feature      = gb.features.select { |f| _is_source_feature?(f.feature) }.first
        taxon_db_xref       = source_feature.qualifiers.select { |q| _is_db_taxon_xref_qualifier?(q) }.first
        ncbi_taxon_id       = taxon_db_xref.value.gsub('taxon:', '').to_i

        ranked = NcbiRankedLineage.find_by(tax_id: ncbi_taxon_id)
        return ranked
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

  ## UNUSED
    def _lowest_rank(row, element_of)
        _possible_taxa.each do |t|
            return row[element_of[t]] unless row[element_of[t]].blank?
            return nil if row[element_of[t]] == _possible_taxa.last
        end
    end
end
