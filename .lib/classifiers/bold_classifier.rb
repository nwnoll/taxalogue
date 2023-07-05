# frozen_string_literal: true

class BoldClassifier
    include StringFormatting
    attr_reader :file_name, :params, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :markers, :regexes_for_markers, :taxonomy_params, :region_params

    @@index_by_column_name = nil
    POSSIBLE_RANKS = ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'class_name', 'phylum_name']
    
    ## Had to include these mappings from phylum to kingdom, since I do not get the kingdom
    #  information with the download record and this information should be available for 
    #  further downstream processing
   # KINGDOM_BY_PHYLUM = {
   #     "Acanthocephala" => "Metazoa",
   #     "Acoelomorpha" => "Metazoa",
   #     "Annelida" => "Metazoa",
   #     "Arthropoda" => "Metazoa",
   #     "Brachiopoda" => "Metazoa",
   #     "Bryozoa" => "Metazoa",
   #     "Chaetognatha" => "Metazoa",
   #     "Chordata" => "Metazoa",
   #     "Cnidaria" => "Metazoa",
   #     "Ctenophora" => "Metazoa",
   #     "Cycliophora" => "Metazoa",
   #     "Echinodermata" => "Metazoa",
   #     "Entoprocta" => "Metazoa",
   #     "Gastrotricha" => "Metazoa",
   #     "Gnathostomulida" => "Metazoa",
   #     "Hemichordata" => "Metazoa",
   #     "Kinorhyncha" => "Metazoa",
   #     "Mollusca" => "Metazoa",
   #     "Nematoda" => "Metazoa",
   #     "Nematomorpha" => "Metazoa",
   #     "Nemertea" => "Metazoa",
   #     "Onychophora" => "Metazoa",
   #     "Phoronida" => "Metazoa",
   #     "Placozoa" => "Metazoa",
   #     "Platyhelminthes" => "Metazoa",
   #     "Porifera" => "Metazoa",
   #     "Priapulida" => "Metazoa",
   #     "Rhombozoa" => "Metazoa",
   #     "Rotifera" => "Metazoa",
   #     "Sipuncula" => "Metazoa",
   #     "Tardigrada" => "Metazoa",
   #     "Xenacoelomorpha" => "Metazoa",
   #     "Bryophyta" => "Plantae",
   #     "Chlorophyta" => "Plantae",
   #     "Lycopodiophyta" => "Plantae",
   #     "Magnoliophyta" => "Plantae",
   #     "Pinophyta" => "Plantae",
   #     "Pteridophyta" => "Plantae",
   #     "Rhodophyta" => "Plantae",
   #     "Ascomycota" => "Fungi", 
   #     "Basidiomycota" => "Fungi", 
   #     "Chytridiomycota" => "Fungi", 
   #     "Glomeromycota" => "Fungi", 
   #     "Myxomycota" => "Fungi", 
   #     "Zygomycota" => "Fungi",
   #     "Chlorarachniophyta" => "Protista", 
   #     "Ciliophora" => "Protista", 
   #     "Heterokontophyta" => "Protista", 
   #     "Pyrrophycophyta" => "Protista"
   # }

    ## added 15-06-2023
    ## from bold release April 2023
    ## changed Animalai to Metazoa
    KINGDOM_BY_PHYLUM = {
        "Arthropoda"            =>"Metazoa",
        "Annelida"              =>"Metazoa",
        "Chordata"              =>"Metazoa",
        "Cnidaria"              =>"Metazoa",
        "Echinodermata"         =>"Metazoa",
        "Mollusca"              =>"Metazoa",
        "Nemertea"              =>"Metazoa",
        "Porifera"              =>"Metazoa",
        "Phoronida"             =>"Metazoa",
        "Brachiopoda"           =>"Metazoa",
        "Hemichordata"          =>"Metazoa",
        "Magnoliophyta"         =>"Plantae",
        "Ascomycota"            =>"Fungi",
        "Riboviria"             =>"Unknown",
        "Chlorophyta"           =>"Plantae",
        "Bryozoa"               =>"Metazoa",
        "Rhodophyta"            =>"Protista",
        "Ochrophyta"            =>"Protista",
        "Proteobacteria"        =>"Bacteria",
        "Actinobacteria"        =>"Bacteria",
        "Firmicutes"            =>"Bacteria",
        "Acanthocephala"        =>"Metazoa",
        "Pinophyta"             =>"Plantae",
        "Nematoda"              =>"Metazoa",
        "Bacillariophyta"       =>"Protista",
        "Basidiomycota"         =>"Fungi",
        "Pteridophyta"          =>"Plantae",
        "Rotifera"              =>"Metazoa",
        "Platyhelminthes"       =>"Metazoa",
        "Nematomorpha"          =>"Metazoa",
        "Ciliophora"            =>"Protista",
        "Heterokontophyta"      =>"Protista",
        "Chaetognatha"          =>"Metazoa",
        "Onychophora"           =>"Metazoa",
        "Air"                   =>"Unknown",
        "Gnetophyta"            =>"Plantae",
        "Cycadophyta"           =>"Plantae",
        "Lycopodiophyta"        =>"Plantae",
        "Haptophyta"            =>"Protista",
        "Ctenophora"            =>"Metazoa",
        "Bryophyta"             =>"Plantae",
        "Marchantiophyta"       =>"Plantae",
        "Priapulida"            =>"Metazoa",
        "Streptophyta"          =>"Plantae",
        "Amoebozoa"             =>"Protista",
        "Myzozoa"               =>"Protista",
        "Cercozoa"              =>"Protista",
        "Charophyta"            =>"Plantae",
        "Chlorarachniophyta"    =>"Protista",
        "Cryptophyta"           =>"Protista",
        "Zygomycota"            =>"Fungi",
        "Myxomycota"            =>"Fungi",
        "Anthocerotophyta"      =>"Plantae",
        "Euglenida"             =>"Protista",
        "Pyrrophycophyta"       =>"Protista",
        "Tardigrada"            =>"Metazoa",
        "Xenacoelomorpha"       =>"Metazoa",
        "Unknown"               =>"Unknown",
        "Gastrotricha"          =>"Metazoa",
        "Bolidophyceae"         =>"Protista",
        "Chrysophyta"           =>"Protista",
        "Aurearenophyceae"      =>"Protista",
        "Glaucophyta"           =>"Protista",
        "Foraminifera"          =>"Protista",
        "Deinococcus-Thermus"   =>"Bacteria",
        "Chloroflexi"           =>"Bacteria",
        "Bacteroidetes"         =>"Bacteria",
        "Euryarchaeota"         =>"Bacteria",
        "Crenarchaeota"         =>"Bacteria",
        "Acidobacteria"         =>"Bacteria",
        "Cyanobacteria"         =>"Bacteria",
        "Aquificae"             =>"Bacteria",
        "Armatimonadetes"       =>"Bacteria",
        "Gemmatimonadetes"      =>"Bacteria",
        "Chlamydiae"            =>"Bacteria",
        "Chlorobi"              =>"Bacteria",
        "Deferribacteres"       =>"Bacteria",
        "Planctomycetes"        =>"Bacteria",
        "Spirochaetes"          =>"Bacteria",
        "Thaumarchaeota"        =>"Bacteria",
        "Chytridiomycota"       =>"Fungi",
        "Glomeromycota"         =>"Fungi",
        "Ginkgophyta"           =>"Plantae",
        "Psilophyta"            =>"Plantae",
        "Rhombozoa"             =>"Metazoa",
        "Entoprocta"            =>"Metazoa",
        "Apicomplexa"           =>"Protista",
        "Kinorhyncha"           =>"Metazoa",
        "Gnathostomulida"       =>"Metazoa",
        "Placozoa"              =>"Metazoa",
        "Cycliophora"           =>"Metazoa",
        "Neocallimastigomycota" =>"Fungi",
        "Microsporidia"         =>"Fungi",
        "Marine"                =>"Unknown",
        "Prime"                 =>"Unknown",
        "Eukarya_unassigned"    =>"Protista",
        "Chromerida"            =>"Protista",
        "Terrestrial"           =>"Unknown"
    }

    def initialize(file_name:, params:, file_manager:)
        @file_name            = file_name
        @params               = params
        @query_taxon_object   = params[:taxon_object]
        @query_taxon_name     = query_taxon_object.canonical_name
        @query_taxon_rank     = query_taxon_object.taxon_rank
        @fast_run             = params[:fast_run]
        @markers              = params[:marker_objects]
        @regexes_for_markers  = Marker.regexes(db: self.class, markers: markers)
        @file_manager         = file_manager
        @filter_params        = params[:filter]
        @taxonomy_params      = params[:taxonomy]
        @region_params        = params[:region]
    end


    def run
        MiscHelper.OUT_header('Starting to classify BOLD downloads')
        puts
        
        specimens_of_taxon = Hash.new { |hash, key| hash[key] = {} }
        specimens_of_sequence = Hash.new
        file_of = MiscHelper.create_output_files(file_manager: file_manager, query_taxon_name: query_taxon_name, file_name: file_name, params: params, source_db: 'bold') unless DerepHelper.do_derep 

        file = File.file?(file_name) ? File.open(file_name, 'r') : nil
        return nil if file.nil?
        
        @@index_by_column_name = MiscHelper.generate_index_by_column_name(file: file, separator: "\t")
        
        file.each do |row|
            _matches_query_taxon(row.scrub!) ? nil : next if fast_run

            scrubbed_row = row.scrub!.chomp.split("\t")
            specimen = _get_specimen(row: scrubbed_row)
            next if specimen.nil? || specimen.sequence.nil? || specimen.sequence.empty?
            next unless specimen_is_from_area(specimen: specimen, region_params: region_params) if region_params.any?
            
            SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
        end
        
        
        puts "file '#{file_name}' was read"
        puts 

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

            DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params, query_taxon_name, 'bold')
            puts 'dereplication finished'
            puts
        else
            ## TODO: Check if it should also be done for Comparison
            OutputFormat::Tsv.rewind
            file_of.each { |fc, fh| fh.close }
        end

        return nil
    end

    def self.get_taxon_object_for_unmapped(first_specimen)
        lineage = BoldClassifier.create_lineage_ary(first_specimen)
        return nil if lineage.size > 7
        return nil if lineage.size < 1
        
        if $params[:classify][:bold_release]

            taxon_rank      = first_specimen[@@index_by_column_name["identification_rank"]]
            taxon_rank      = BoldClassifier.get_taxon_rank_field(first_specimen)

            phylum          = first_specimen[@@index_by_column_name["phylum"]]
            regnum          = KINGDOM_BY_PHYLUM[phylum]
            classis         = first_specimen[@@index_by_column_name["class"]]
            ordo            = first_specimen[@@index_by_column_name["order"]]
            familia         = first_specimen[@@index_by_column_name["family"]]
            genus           = first_specimen[@@index_by_column_name["genus"]]
            canonical_name  = first_specimen[@@index_by_column_name["identification"]]
            
        else
            taxon_rank_column_name  = BoldClassifier.get_taxon_rank_field(first_specimen)
            taxon_rank              = taxon_rank_column_name[0 .. -6]

            phylum          = first_specimen[@@index_by_column_name["phylum_name"]]
            regnum          = KINGDOM_BY_PHYLUM[phylum]
            classis         = first_specimen[@@index_by_column_name["class_name"]]
            ordo            = first_specimen[@@index_by_column_name["order_name"]]
            familia         = first_specimen[@@index_by_column_name["family_name"]]
            genus           = first_specimen[@@index_by_column_name["genus_name"]]
            canonical_name  = first_specimen[@@index_by_column_name[taxon_rank_column_name]]
        end

        obj = OpenStruct.new(
            taxon_id:               'no_info',
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
        
        return obj
    end

    def self.create_lineage_ary(specimen_data)
        lineage_ary = []

        POSSIBLE_RANKS.reverse.each do |taxon|
            next if taxon == "subspecies_name"
            taxon = release_header_of[taxon] if $params[:classify][:bold_release]

            lineage_ary.push(specimen_data[@@index_by_column_name[taxon]]) unless specimen_data[@@index_by_column_name[taxon]].blank?
        end

        return lineage_ary
    end

    def self.find_lowest_ranking_taxon(specimen_data)
        
        if $params[:classify][:bold_release]
            return nil if specimen_data[@@index_by_column_name["identification"]].nil? || specimen_data[@@index_by_column_name["identification"]].blank?
            return specimen_data[@@index_by_column_name["identification"]]
        end


        POSSIBLE_RANKS.each do |taxon|
            return specimen_data[@@index_by_column_name[taxon]] unless specimen_data[@@index_by_column_name[taxon]].blank?
            return nil if specimen_data[@@index_by_column_name[taxon]] == POSSIBLE_RANKS.last
        end
    end

    def self.get_taxon_rank_field(specimen_data)
        POSSIBLE_RANKS.each do |taxon|
            taxon = release_header_of[taxon] if $params[:classify][:bold_release]

            return taxon unless specimen_data[@@index_by_column_name[taxon]].blank?
        end
    end

    private
    def _get_specimen(row:)
        
        if $params[:classify][:bold_release]
        
            identifier        = row[@@index_by_column_name["processid"]]
            source_taxon_name = row[@@index_by_column_name["identification"]]
            sequence          = row[@@index_by_column_name["nucraw"]]
            return nil if sequence.nil? || sequence.blank?

            sequence  = FilterHelper.filter_seq(sequence, filter_params)
            marker    = row[@@index_by_column_name["marker_code"]]
            location = row[@@index_by_column_name["country"]]
            if row[@@index_by_column_name["coord"]]
                lat, long = row[@@index_by_column_name["coord"]].gsub(/[\(\)]/, "").split(",")
            else
                lat, long = nil
            end
        else
        
            identifier        = row[@@index_by_column_name["processid"]]
            source_taxon_name = BoldClassifier.find_lowest_ranking_taxon(row)
            sequence          = row[@@index_by_column_name['nucleotides']]
            return nil if sequence.nil? || sequence.blank?
            
            sequence  = FilterHelper.filter_seq(sequence, filter_params)
            marker    = row[@@index_by_column_name["markercode"]]
            location  = row[@@index_by_column_name["country"]]
            lat       = row[@@index_by_column_name["lat"]]
            long      = row[@@index_by_column_name["lon"]]
        end

        return nil unless _belongs_to_correct_marker?(marker)
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

    def _belongs_to_correct_marker?(marker)
        regexes_for_markers === marker
    end

    def self.get_source_lineage(row)
        lineage_ary = BoldClassifier.create_lineage_ary(row)
    
        OpenStruct.new(
            name: BoldClassifier.find_lowest_ranking_taxon(row),
            combined: lineage_ary
        )
    end

    def _matches_query_taxon(row)
      /#{query_taxon_name}/.match?(row) || /#{file_name.basename.sub_ext('')}/.match?(row)
    end

    def _specimen_header_of_release_file_header()
        {
            "processid"=>"processid",
            "sampleid"=>"sampleid",
            "specimenid"=>"recordID",
            "museumid"=>"TODO",
            "fieldid"=>"fieldnum",
            "inst"=>"institution_storing",
            "bin_uri"=>"bin_uri",
            "identification"=>"TO IMPLEMENT",
            "funding_src"=>"TODO",
            "kingdom"=> "TO IMPLEMENT",
            "phylum"=>"phylum_name",
            "class"=>"class_name",
            "order"=>"order_name",
            "family"=>"family_name",
            "subfamily"=>"subfamily_name",
            "genus"=>"genus_name",
            "species"=>"species_name",
            "subspecies"=>"subspecies_name",
            "identified_by"=>"identification_provided_by",
            "voucher_type"=>"voucher_status",
            "collectors"=>"collectors",
            "collection_date"=>"collectiondate_start",
            "collection_date_accuracy"=>"TODO",
            "life_stage"=>"lifestage",
            "sex"=>"sex",
            "reproduction"=>"reproduction",
            "extrainfo"=>"extrainfo",
            "notes"=>"notes",
            "coord"=>"TO IMPLEMENT",
            "coord_source"=>"coord_source",
            "coord_accuracy"=>"coord_accuracy",
            "elev"=>"elev",
            "depth"=>"depth",
            "elev_accuracy"=>"elev_accuracy",
            "depth_accuracy"=>"depth_accuracy",
            "country"=>"country",
            "province"=>"province_state",
            "country_iso"=>"TODO",
            "region"=>"region",
            "sector"=>"sector",
            "site"=>"exactsite",
            "collection_time"=>"collectiontime",
            "habitat"=>"habitat",
            "collection_note"=>"collection_note",
            "associated_taxa"=>"associated_taxa",
            "associated_specimen"=>"associated_specimens",
            "species_reference"=>"identification_reference",
            "identification_method"=>"identification_method",
            "recordset_code_arr"=>"TODO",
            "gb_acs"=>"genbank_accession",
            "marker_code"=>"markercode",
            "nucraw"=>"nucleotides",
            "sequence_run_site"=>"TODO",
            "processid_minted_date"=>"TODO",
            "sequence_upload_date"=>"TODO",
            "identification_rank"=>"TO IMPLEMENT"
        }
    end

    def self.release_header_of()
        {
            "processid"=>"processid",
            "sampleid"=>"sampleid",
            "recordID"=>"specimenid",
            "TODO"=>"sequence_upload_date",
            "fieldnum"=>"fieldid",
            "institution_storing"=>"inst",
            "bin_uri"=>"bin_uri",
            "TO IMPLEMENT"=>"identification_rank",
            "phylum_name"=>"phylum",
            "class_name"=>"class",
            "order_name"=>"order",
            "family_name"=>"family",
            "subfamily_name"=>"subfamily",
            "genus_name"=>"genus",
            "species_name"=>"species",
            "subspecies_name"=>"subspecies",
            "identification_provided_by"=>"identified_by",
            "voucher_status"=>"voucher_type",
            "collectors"=>"collectors",
            "collectiondate_start"=>"collection_date",
            "lifestage"=>"life_stage",
            "sex"=>"sex",
            "reproduction"=>"reproduction",
            "extrainfo"=>"extrainfo",
            "notes"=>"notes",
            "coord_source"=>"coord_source",
            "coord_accuracy"=>"coord_accuracy",
            "elev"=>"elev",
            "depth"=>"depth",
            "elev_accuracy"=>"elev_accuracy",
            "depth_accuracy"=>"depth_accuracy",
            "country"=>"country",
            "province_state"=>"province",
            "region"=>"region",
            "sector"=>"sector",
            "exactsite"=>"site",
            "collectiontime"=>"collection_time",
            "habitat"=>"habitat",
            "collection_note"=>"collection_note",
            "associated_taxa"=>"associated_taxa",
            "associated_specimens"=>"associated_specimen",
            "identification_reference"=>"species_reference",
            "identification_method"=>"identification_method",
            "genbank_accession"=>"gb_acs",
            "markercode"=>"marker_code",
            "nucleotides"=>"nucraw"
        } 
    end

end
