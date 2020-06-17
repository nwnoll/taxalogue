# frozen_string_literal: true

require 'csv'
class GbifTaxonImporter
  attr_reader :file_name

  def initialize(file_name:)
    @file_name        = file_name
  end

  def run
    file = File.open(file_name, 'r')


    csv = CSV.new(file, headers: true, col_sep: "\t", liberal_parsing: true)
    taxa = []
    columns = GbifTaxon.column_names - ['id']
    csv.each do |row|
      next if row['taxonRank'] == 'unranked'
      taxa.push(row.to_h.values)
      if taxa.size % 100_000 == 0
        _batch_import(columns, taxa)
        taxa = []
      end
    end
    _batch_import(columns, taxa)
  end

  private
  def _batch_import(columns, taxa)
    GbifTaxon.import columns, taxa, validate: false
  end
end
