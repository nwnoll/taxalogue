# frozen_string_literal: true

class NcbiGenbankExtractor
    attr_reader :file_name, :taxon_name, :markers, :regexes_for_markers, :result_file_name

    def initialize(file_name:, taxon_name:, markers:, result_file_name:)
        @file_name            = file_name
        @taxon_name           = taxon_name
        @markers              = markers
        @regexes_for_markers  = Marker.regexes(db: self.class, markers: markers)
        @result_file_name     = result_file_name
    end


    def run
        file = File.open(file_name, 'r')
        ff = Bio::FlatFile.new(Bio::GenBank, file)

        specimens_of_taxon = Hash.new { |hash, key| hash[key] = {} }

        ff.each_entry do |gb|
            next unless _matches_query_taxon(gb)

            features_of_gene  = gb.features.select { |f| _is_gene_feature?(f.feature) && _is_gene_of_marker?(f.qualifiers) && _is_no_pseudogene?(f.qualifiers) }
            next unless features_of_gene.size == 1 ## TODO: why 1 ?
            
            nucs = gb.naseq.splicing(features_of_gene.first.position).to_s
            next if nucs.nil? || nucs.empty?

            nucs.upcase!

            specimen = _get_specimen(gb: gb, nucs: nucs)

            SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
        end

        tsv   = File.open(result_file_name.sub_ext('.tsv'), 'w')
        fasta = File.open(result_file_name.sub_ext('.fas'), 'w')

        tsv.puts "identifier\tkingdom\tphylum\tclass\torder\tfamily\tgenus\tspecies\tlocation\tlatitude\tlongitude\tsequence"
    
        specimens_of_taxon.keys.each do |taxon_name|
            specimens_of_taxon[taxon_name][:data].each do |data|
                tsv.puts "#{data[:identifier]}\t\t\t\t\t\t\t#{taxon_name}\t#{data[:location]}\t#{data[:latitude]}\t#{data[:longitude]}\t#{data[:sequence]}"
                fasta.puts ">#{data[:identifier]}|#{taxon_name}"
                fasta.puts "#{data[:sequence]}"
            end
        end

        OutputFormat::Tsv.rewind

        tsv.close
        fasta.close
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
        source_features               = _get_source_features(gb)
        location                      = _get_country_value(source_features).first
        lat_lon                       = _get_lat_lon_value(source_features)
        lat                           = lat_lon.first
        long                          = lat_lon.last

        specimen                      = Specimen.new
        specimen.identifier           = gb.accession
        specimen.sequence             = nucs
        specimen.source_taxon_name    = source_taxon_name
        specimen.taxon_name           = source_taxon_name
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
        /#{taxon_name}/.match?(gb.taxonomy) || /#{taxon_name}/.match?(gb.organism)
    end
end