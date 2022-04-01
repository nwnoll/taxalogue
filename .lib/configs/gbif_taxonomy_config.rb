# frozen_string_literal: true

class GbifTaxonomyConfig
    attr_reader :name
    def initialize()
        @name = 'GBIF_TAXONOMY'
    end

    def downloader
        HttpDownloader
    end

    def importers
        {
            'GbifTaxonomyImporter': 'Taxon.tsv',
        }
    end

    def address
        'https://hosted-datasets.gbif.org/datasets/backbone/current/backbone.zip'
    end

    def file_type
        'zip'
    end

    def file_manager
        FileManager.new(name: name, versioning: false, base_dir: 'downloads/', config: self)
    end
end
  