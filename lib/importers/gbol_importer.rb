# frozen_string_literal: true

class GbolImporter
  include StringFormatting
  include GeoUtils
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :taxonomy_params, :region_params

  def self.get_source_lineage(row)
    OpenStruct.new(
      name:     row["Species"],
      combined: row['HigherTaxa'].split(', ')
    )
  end

  def initialize(file_name:, query_taxon_object:, fast_run: false, file_manager:, filter_params: nil, taxonomy_params:, region_params: nil)
    @file_name                = file_name
    @query_taxon_object       = query_taxon_object
    @query_taxon_name         = query_taxon_object.canonical_name
    @query_taxon_rank         = query_taxon_object.taxon_rank
    @fast_run                 = fast_run
    @file_manager             = file_manager
    @filter_params            = filter_params
    @taxonomy_params          = taxonomy_params
    @region_params            = region_params
  end

  def run
    specimens_of_taxon  = Hash.new { |hash, key| hash[key] = {} }

    Helper.extract_zip(name: file_name, destination: file_name.dirname, files_to_extract: [file_name.basename, 'metadata.xml'])
    ## TODO:
    ## NEXT:
    ## whats correct?
    # Helper.extract_zip(name: file_name, destination: file_name.dirname, files_to_extract: [file_name.basename.sub_ext('.csv').to_s, 'metadata.xml'])
    
    csv_file_name = file_name.sub_ext('.csv')
    csv_file = File.open(csv_file_name, 'r')
    csv_object = CSV.new(csv_file, headers: true, col_sep: "\t", liberal_parsing: true)


    csv_object.each do |row|
      _matches_query_taxon(row) ? nil : next if fast_run

      specimen = _get_specimen(row: row)
      next if specimen.nil? || specimen.sequence.nil? || specimen.sequence.empty?

      SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
    end

    tsv             = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_gbol_fast_#{fast_run}_output.tsv", OutputFormat::Tsv)
    fasta           = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_gbol_fast_#{fast_run}_output.fas", OutputFormat::Fasta)
    comparison_file = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_gbol_fast_#{fast_run}_comparison.tsv",   OutputFormat::Comparison)
    

    count = 0
    specimens_of_taxon.keys.each do |taxon_name|
      count += 1
      # break if count == 250
      nomial              = specimens_of_taxon[taxon_name][:nomial]
      first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
      specimen = specimens_of_taxon[taxon_name][:obj]
      

      specimen_is_from_area(specimen: specimen, region_params: region_params) if region_params
      next

      ## NEXT implement location and region specific databases
      puts "loc: #{specimen.location}"
      # puts "lat: #{specimen.lat}"
      # puts "long: #{specimen.long}"


      if specimen.lat && specimen.long
        specimen_locality = Geokit::LatLng.new(specimen.lat, specimen.long)
        polly = $polygons_of['Western European broadleaf forests'].first
        pollies = $areas_of['Western European broadleaf forests']
        pollies = $areas_of['PA']
        # puts pollies.size
        # pollies.each do |polygon|
        #   if polygon.contains?(specimen_locality)
        #     puts "region: Western European broadleaf forests"
        #     puts "region: Palearctic"
        #     next 
        #   end
        # end

        $areas_of.each do |region, areas|
          areas.each do |area|
            if area.contains?(specimen_locality)
              puts region
            end
          end
        end
        # if polly.contains?(specimen_locality)
        #   puts "region: Western European broadleaf forests"
        #   next
        # end
        next
        # next unless specimen.lat.to_f.positive? && specimen.long.to_f.positive?
        # $splitted_areas_of[:east][:north].each do |region_name, areas|
        #   rect_polygon = areas.first
        #   next unless rect_polygon.contains?(specimen_locality)
        #   is_in_area = false
        #   areas.drop(1).each do |area|
        #     is_in_area = area.contains?(specimen_locality)
        #     break if is_in_area
        #   end

        #   if is_in_area
        #     # puts "region: #{region_name}"
        #     break
        #   end
        # end
      end

      # if specimen.lat && specimen.long
      #   $areas_of.each do |region_name, areas|
      #     is_in_area = false
      #     areas.each do |area|
      #       is_in_area = area.contains?(Geokit::LatLng.new(specimen.lat, specimen.long))
      #       break if is_in_area
      #     end
      #     puts "region: #{region_name}" and break if is_in_area
      #   end
      # end

      # if specimen.location
      #   locations = specimen.location.split(', ')
      #   locations.each do |loc|
      #     c = LocationSearch.by_name(loc)
      #     # p c.nil? ? next : c
      #   end
      # end
      # puts
      # puts
      ## europe LocationSearch.by_region('Europe')
      ## europe.each { |o| p o.name }
      next

      taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)
      
      next unless taxonomic_info
      next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

      syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [Helper.get_source_db(taxonomy_params)])
      OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms: syn.synonyms[Helper.get_source_db(taxonomy_params)], used_taxonomy: Helper.get_source_db(taxonomy_params))

      # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms: syn.synonyms)

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
  
  private
  def _get_specimen(row:)
    identifier                    = row["CatalogueNumber"]
    source_taxon_name             = row["Species"]
    sequence                      = row['BarcodeSequence']
    location                      = row["Location"]
    lat                           = row["Latitude"]
    long                          = row["Longitude"]
    sequence                      = Helper.filter_seq(sequence, filter_params)

    return nil if sequence.nil?

    nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)

    specimen                      = Specimen.new
    specimen.identifier           = identifier
    specimen.sequence             = sequence
    specimen.source_taxon_name    = source_taxon_name
    specimen.taxon_name           = nomial.name
    specimen.nomial               = nomial
    specimen.location             = location
    specimen.lat                  = lat
    specimen.long                 = long
    specimen.first_specimen_info  = row
    
    return specimen
  end

  def _matches_query_taxon(row)
    /#{query_taxon_name}/.match?(row["HigherTaxa"]) || /#{query_taxon_name}/.match?(row["Species"])
  end
end
