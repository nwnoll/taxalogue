# frozen_string_literal: true

require 'resolv-replace'
class NcbiApi
    attr_reader :markers, :taxon_name, :max_seq, :file_name

    SearchResult = Struct.new(:web, :key, :count)

    def initialize(markers:, taxon_name:, max_seq: 1, file_name:)
        @markers    = markers
        @taxon_name = taxon_name
        @max_seq    = max_seq
        @file_name   = file_name
    end

    def efetch(retstart: 0, retmax: -1)
        file = File.open(file_name, 'w')
        retmax            = max_seq == -1 ? 500 : max_seq < 500 ? max_seq : 500
        retstart          = retstart
        esearch_result    = _run_esearch

        stop_at = max_seq == -1 ? esearch_result.count : max_seq

            
        until retstart >= stop_at
                url         = "#{_base}efetch.fcgi?db=nucleotide&WebEnv=#{esearch_result.web}&query_key=#{esearch_result.key}&retstart=#{retstart}&retmax=#{retmax}&rettype=gb&retmode=text"
                puts url
                uri         = URI(url)
                # use HTTP downloader
                response    = Net::HTTP.get_response(uri)
                retstart   += retmax

                file.write(response.body)
        end
    end

    private
    def _run_esearch
        query       = CGI::escape(MiscHelper.normalize("#{_taxon_query}#{_marker_query}#{_exclusion_query}"))
        url         = "#{_base}esearch.fcgi?db=nucleotide&term=#{query}&usehistory=y"
        uri         = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)

        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        
        #response    = Net::HTTP.get_response(uri)

        web         = $1        if response.body =~ /<WebEnv>(\S+)<\/WebEnv>/
        key         = $1        if response.body =~ /<QueryKey>(\d+)<\/QueryKey>/
        count       = $1.to_i   if response.body =~ /<Count>(\d+)<\/Count>/
        search_result = SearchResult.new(web, key, count)

        return search_result
    end

    def _base
        'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/'
    end

    def _taxon_query
        "#{taxon_name}[organism] AND "
    end

    def _marker_query
        marker_tags = []
        markers.map { |marker| marker_tags.push(marker.marker_tag) }

        searchterms = []
        marker_tags.each do |tag|
                searchterms = Marker.searchterms_of[tag][:ncbi]
        end
        
        ## TODO
        # when other tha CO1 will be integrated, this has to change
        # best: find each Marker the proper term
        
        searchterms.map!{ |term| term.dup.concat('[gene]')}
        marker_query = searchterms.join(' OR ')

        marker_query.insert(0, '(')
        marker_query.insert(-1, ')')

        return marker_query
    end

    def _exclusion_query
        ' NOT pseudogene'
    end
end
