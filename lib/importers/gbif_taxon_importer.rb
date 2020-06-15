# frozen_string_literal: true

require 'csv'
class GbifTaxonImporter
  attr_reader :file_name

  def initialize(file_name:)
    @file_name        = file_name
  end

  # def self.call(file_name:)
  #   new(file_name: file_name).call
  # end


  def call
    byebug
    file = File.open(file_name, 'r')


    csv = CSV.new(file, headers: true, col_sep: "\t", liberal_parsing: true)
    taxa = []
    columns = GbifTaxon.column_names - ['id']
    csv.each do |row|
      next if row['taxonRank'] == 'unranked'
      taxa.push(row.to_h.values)
      if taxa.size % 100_000 == 0
        puts '... importing 100k records'
        GbifTaxon.import columns, taxa, validate: false
        taxa = []
      end
    end
    puts '... importing last few records'
    GbifTaxon.import columns, taxa, validate: false
  end
end
