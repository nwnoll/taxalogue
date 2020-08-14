# frozen_string_literal: true

class DbJob
attr_reader :taxon, :markers, :taxonomy, :taxon_name
  def initialize(taxon:, markers: nil, taxonomy:)
    @taxon      = taxon
    @taxon_name = taxon.canonical_name
    @markers    = markers
    @taxonomy   = taxonomy
  end

  def run
      
  end
end