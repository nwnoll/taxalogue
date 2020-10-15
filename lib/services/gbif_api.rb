# frozen_string_literal: true

class GbifApi
  attr_reader :path, :query, :response_hash
  def initialize(path: 'species?name=', query:)
    @path  = path
    @query = CGI::escape(Helper.normalize(query.to_s))
    @response_hash = JSON.parse response.body
  end


  def records
    return unless response_hash['results']

    records = []

    response_hash['results'].each do |result|
      taxonomic_status = result['taxonomicStatus']
      records.push(_taxon_object_proxy(taxon: result)) and next if _is_accepted?(taxonomic_status) || _is_doubtful?(taxonomic_status)
      
      if _is_synonym?(taxonomic_status)
        
        accepted_name_usage_id          = result['acceptedKey'].to_s
        records.push(_taxon_object_proxy(taxon: result, comment: :used_accepted_info)) and next if accepted_name_usage_id.blank?
        
        record                          = GbifTaxon.find_by(taxon_id: accepted_name_usage_id)
        records.push(record) and next unless record.nil?

        resp                            = GbifApi.new(path: 'species/', query: accepted_name_usage_id).response_hash
        nubkey                          = resp['nubKey'].to_s
        records.push(_taxon_object_proxy(taxon: resp)) and next if nubkey.blank?

        record_by_nubkey                = GbifTaxon.find_by(taxon_id: nubkey)
        records.push(_taxon_object_proxy(taxon: resp)) and next if record_by_nubkey.nil?

        accepted_id                     = record_by_nubkey.accepted_name_usage_id
        records.push(record_by_nubkey) and next if accepted_id.blank?
        
        record_by_accepted_id_of_nubkey = GbifTaxon.find_by(taxon_id: accepted_id)
        record_by_accepted_id_of_nubkey.nil? ? records.push(record_by_nubkey) : records.push(record_by_accepted_id_of_nubkey)
      end
    end

    gbif_taxon_records = records.select { |record| record.instance_of?(GbifTaxon) }.uniq
    return gbif_taxon_records.empty? ? records : gbif_taxon_records
  end

  def response
    Timeout.timeout(60) { Net::HTTP.get_response(_full_request_uri) }
  end

  private
  def _gbif_api_url
    'https://api.gbif.org/v1/'
  end

  def _full_request_url
    _gbif_api_url.dup.concat(path).concat(query)
  end

  def _full_request_uri
     URI(_full_request_url)
  end

  def _is_accepted?(status)
    status =~ /ACCEPTED/i
  end

  def _is_doubtful?(status)
    status =~ /DOUBTFUL/i
  end

  def _is_synonym?(status)
    status =~ /SYNONYM/i
  end

  def _fuzzy_path
    'species/match?strict=true&name'
  end


  def _taxon_object_proxy(taxon:, comment: nil)
    return if taxon.nil?
    
    taxon['rank'].blank? ? taxon_rank = 'unranked' : taxon_rank = taxon['rank'].downcase
    taxon_rank.gsub!('sub', '') if taxon_rank =~ /sub/
    
    taxonomic_status  = taxon['taxonomicStatus'].to_s.downcase
    taxonomic_status  = 'accepted' if comment == :used_accepted_info
    canonical_name    = _get_canonical_name(taxon)
    combined          = _get_combined(taxon)
    
    OpenStruct.new(
      regnum:                 taxon['kingdom'],
      phylum:                 taxon['phylum'],
      classis:                taxon['class'],
      ordo:                   taxon['order'],
      familia:                taxon['family'],
      genus:                  taxon['genus'],
      canonical_name:         canonical_name,
      taxonomic_status:       taxonomic_status,
      taxon_rank:             taxon_rank,
      combined:               combined,
      accepted_name_usage_id: nil,
      comment:                comment
    )
  end

  def _get_canonical_name(taxon)
    canonical_name = ''
    possible_ranks = GbifTaxon.possible_ranks
    possible_ranks.reverse.each { |rank| canonical_name = taxon[rank] unless taxon[rank].blank? }

    return canonical_name
  end

  def _get_combined(taxon)
    combined = []
    possible_ranks = GbifTaxon.possible_ranks
    possible_ranks.reverse.each { |rank| combined.push(taxon[rank]) unless taxon[rank].blank? }
    
    return combined
  end
end
