# frozen_string_literal: true

class NcbiTaxonomyConfig
    attr_reader :name
    def initialize()
        @name            = 'NCBI_TAXONOMY'
    end
  
    def downloader
        HttpDownloader
    end

    def importers
        {
            'NcbiNameImporter': 'names.dmp',
            'NcbiRankedLineageImporter': 'rankedlineage.dmp',
            'NcbiNodeImporter': 'nodes.dmp'
        }
    end
  
    def address
        'https://ftp.ncbi.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.zip'
    end

    def file_type
        'zip'
    end

    def file_manager
        FileManager.new(name: name, versioning: false, base_dir: 'downloads/', config: self)
    end
end