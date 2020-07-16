# frozen_string_literal: true

class Marker
    attr_reader :query_marker_name, :marker_tag

    def self.regexes(db:, markers:)
        p markers
        return markers.first.regex(db: db) if markers.size == 1

        regexes = []
        markers.each do |marker|
            regexes.push(marker.regex(db: db))
        end
        
        Regexp.union(regexes)
    end

    def initialize(query_marker_name:)
        @query_marker_name  = query_marker_name
        marker_tag          = _marker_tag(query_marker_name: query_marker_name)
    end

    def regex(db:)
        marker_tag  = _marker_tag(query_marker_name: query_marker_name)
        db_tag      = _db_tag(db: db)

        _regex_of[marker_tag][db_tag]
    end

    private
    def _marker_tag(query_marker_name:)
        regex_of = _regex_of
        if regex_of[:co1][:all] === query_marker_name
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
        [NcbiGenbankImporter, NcbiGenbankJob, NcbiGenbankConfig]
    end

    def _gbol_classes
        [GbolImporter, GbolJob, GbolConfig]
    end

    def _bold_classes
        [BoldImporter, BoldJob, BoldConfig]
    end

    def _regex_of
        regex_of = Hash.new { |hash, key| hash[key] = {} }

        regex_of[:co1][:all]    = Regexp.new('^cox1$|^co1$|^coi$|^cytochrome1$|^cytochromeone$', Regexp::IGNORECASE)
        regex_of[:co1][:ncbi]   = Regexp.new('cox1|co1|coi|cytochrome oxidase 1|cytochrome oxidase one', Regexp::IGNORECASE)
        regex_of[:co1][:gbol]   = Regexp.new('.*')
        regex_of[:co1][:bold]   = Regexp.new('COI-5P|COI-3P', Regexp::IGNORECASE)

        return regex_of
    end

    def _available_markers
        ['co1'].join(' or/and ')
    end
end