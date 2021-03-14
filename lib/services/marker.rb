# frozen_string_literal: true

class Marker
    attr_reader :query_marker_name, :marker_tag

    def initialize(query_marker_name:)
        @query_marker_name  = query_marker_name
        @marker_tag         = _marker_tag(query_marker_name: query_marker_name)
    end


    def self.regexes(db:, markers:)
        return markers.first.regex(db: db) if markers.size == 1

        regexes = []
        markers.each do |marker|
            regexes.push(marker.regex(db: db))
        end
        
        Regexp.union(regexes)
    end

    def self.searchterms_of
        searchterms_of = Hash.new { |hash, key| hash[key] = {} }

        searchterms_of[:co1][:all]    = ['^cox1$','^co1$', '^coi$', '^cytochrome1$', '^cytochromeone$']
        searchterms_of[:co1][:ncbi]   = ['^cox1$', '^co1$', '^coi$', '^cytochrome oxidase 1$', '^cytochrome oxidase I$', '^cytochrome oxidase one$', '^cytochrome oxidase subunit 1$', '^cytochrome oxidase subunit I$', '^cytochrome oxidase subunit one$']
        searchterms_of[:co1][:gbol]   = ['.*']
        searchterms_of[:co1][:bold]   = ['COI-5P']

        return searchterms_of
    end

    def regex(db:)
        db_tag      = _db_tag(db: db)
        _to_regex(self.class.searchterms_of[marker_tag][db_tag])
    end

    private
    def _marker_tag(query_marker_name:)
        searchterms_of = self.class.searchterms_of
        if _to_regex(searchterms_of[:co1][:all]) === query_marker_name
            return :co1
        else
            abort "Marker: marker is not available please use #{_available_markers}.\nUse a comma separated list without any spaces like: coi,rBcl "
        end
    end

    def _db_tag(db:)
        if _ncbi_classes.member? db.class
            return :ncbi
        elsif _gbol_classes.member? db.class
            return :gbol
        elsif _bold_classes.member? db.class
            return :bold
        end
    end

    def _ncbi_classes
        [NcbiGenbankImporter, NcbiGenbankJob, NcbiGenbankConfig, NcbiApi, NcbiGenbankExtractor]
    end

    def _gbol_classes
        [GbolImporter, GbolJob, GbolConfig]
    end

    def _bold_classes
        [BoldImporter, BoldJob, BoldConfig]
    end

    def _to_regex(array_of_searchterms)
        Regexp.new(array_of_searchterms.join('|'), Regexp::IGNORECASE)
    end

    def _available_markers
        ['co1'].join(' or/and ')
    end
end