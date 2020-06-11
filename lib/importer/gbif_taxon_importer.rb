# frozen_string_literal: true

require 'csv'
class GbifTaxonImporter
  def self.import(file_name)
    file = File.open(file_name, 'r')


    csv = CSV.new(file, headers: true, col_sep: "\t", liberal_parsing: true)
    taxa = []
    columns = GbifTaxon.column_names - ['id']
    csv.each do |row|
      next if row['taxon_rank'] == 'unranked'
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
