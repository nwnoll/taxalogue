# frozen_string_literal: true

class GbifHomonymImporter
      attr_reader :file_name

      def initialize(file_name:)
            @file_name        = file_name
      end

      def run
            file = File.open(file_name, 'r')

            file.readline # skip first line

            csv = CSV.new(file, headers: false, col_sep: "\t", liberal_parsing: true)

            homonyms = []
            csv.each { |row| row[2].nil? ? nil : row[2].downcase!; homonyms.push(row) }

            columns = GbifHomonym.column_names - ['id']
            
            GbifHomonym.import columns, homonyms, validate: false
      end
end
