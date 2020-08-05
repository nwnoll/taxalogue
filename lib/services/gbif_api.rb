# frozen_string_literal: true
require 'net/http'
require 'json'
require 'ostruct'
require 'timeout'

class GbifApi
  attr_reader :path, :query, :response_hash
  def initialize(path: 'species?name=', query:)
    @path  = path
    @query = CGI::escape(Helper.normalize(query.to_s))
    @response_hash = JSON.parse response.body
  end

  def exact_match
    _taxon_lineage(_first_accepted_exact_taxon)
  end

  def fuzzy_match
    _taxon_lineage(_first_accepted_fuzzy_taxon)
  end

  private

  def gbif_api_url
    'https://api.gbif.org/v1/'
  end

  def full_request_url
    gbif_api_url.dup.concat(path).concat(query)
  end

  def full_request_uri
     URI(full_request_url)
  end

  def response
    Timeout.timeout(60) { Net::HTTP.get_response(full_request_uri) }
  end

  def _first_accepted_exact_taxon
    return unless response_hash['results']
    response_hash['results'].each do |result|
      taxonomic_status = result['taxonomicStatus']
      if _has_lineage?(result)
        if _is_accepted?(taxonomic_status) || _is_synonym?(taxonomic_status)
          return result
        end
      end
    end
    return nil
  end

  def _is_accepted?(status)
    status == 'ACCEPTED'
  end

  def _is_synonym?(status)
    status == 'SYNONYM'
  end

  def _has_lineage?(result)
    !result['phylum'].nil? && !result['order'].nil?
  end

  def _first_accepted_fuzzy_taxon
    # puts '*' * 100
    # p query
    if response_hash['status'] == 'ACCEPTED'
      # p 'ACCEPTED'
      # p response_hash
      return response_hash
    elsif response_hash['status'] == 'SYNONYM' &&  response_hash['rank'] == 'SPECIES'
       resp = GbifApi.new(path: _fuzzy_path, query: response_hash['species']).response_hash
       # p 'SPECIES'
       # p resp
       return resp
    elsif response_hash['status'] == 'SYNONYM'
       resp = GbifApi.new(path: _fuzzy_path, query: response_hash['species']).response_hash
       # p 'SPECIES'
       # p resp
       return resp
    elsif response_hash['status'] == 'SYNONYM' &&  response_hash['rank'] == 'GENUS'
      resp = GbifApi.new(path: _fuzzy_path, query: response_hash['genus']).response_hash
      p 'GENUS'
      p resp
      return resp
    elsif response_hash['status'] == 'SYNONYM' &&  response_hash['rank'] == 'FAMILY'
      resp = GbifApi.new(path: _fuzzy_path, query: response_hash['family']).response_hash
      # p 'FAMILY'
      # p resp
      return resp
    elsif response_hash['status'] == 'SYNONYM' &&  response_hash['rank'] == 'ORDER'
      resp = GbifApi.new(path: _fuzzy_path, query: response_hash['order']).response_hash
      # p 'ORDER'
      # p resp
      return resp
    elsif response_hash['status'] == 'SYNONYM' &&  response_hash['rank'] == 'PHYLUM'
      resp = GbifApi.new(path: _fuzzy_path, query: response_hash['phylum']).response_hash
      # p 'PHYLUM'
      # p resp
      return resp
    end
  end

  def _fuzzy_path
    'species/match?strict=true&name'
  end

  def _rank_query
    response_hash['rank'].blank? ? nil : response_hash[response_hash['rank'].downcase]
  end

  def _taxon_lineage(taxon)
    return if taxon.nil?
    taxon['rank'].blank? ? taxon_rank = 'unranked' : taxon_rank = taxon['rank'].downcase
    taxon_rank.gsub!('sub', '') if taxon_rank =~ /sub/
    OpenStruct.new(
      regnum: taxon['kingdom'],
      phylum: taxon['phylum'],
      classis: taxon['class'],
      ordo: taxon['order'],
      familia: taxon['family'],
      genus: taxon['genus'],
      canonical_name: taxon[taxon_rank],
      taxon_rank: taxon_rank)
  end
end
