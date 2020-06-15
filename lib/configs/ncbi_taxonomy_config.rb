# frozen_string_literal: true

class NcbiTaxonomyConfig
    attr_reader :file_structure, :name
    def initialize()
        @file_structure  = file_structure
        @name            = 'new_taxdump'
    end
  
    def downloader
        HttpDownloader
    end
  
    def address
        'https://ftp.ncbi.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.zip'
    end

    def file_type
        'zip'
    end
  
    def file_structure
        FileStructure.new(config: self)
    end
end