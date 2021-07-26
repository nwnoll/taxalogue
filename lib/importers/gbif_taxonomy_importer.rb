# frozen_string_literal: true

class GbifTaxonomyImporter
    attr_reader :file_name, :file_manager

    def initialize(file_name:, file_manager:)
        @file_name    = file_name
        @file_manager = file_manager
    end

    def run
        MiscHelper.extract_zip(name: file_manager.file_path, destination: file_manager.dir_path, files_to_extract: [file_name, 'eml.xml'])
        
        file_path = file_manager.dir_path + file_name
        file      = File.open(file_path, 'r')

        csv = CSV.new(file, headers: true, col_sep: "\t", liberal_parsing: true)
        taxa = []
        columns = GbifTaxonomy.column_names - ['id']
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
        GbifTaxonomy.import columns, taxa, validate: false
    end
end
