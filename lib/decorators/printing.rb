module Printing
    module GbifTaxonJob
        def run
            puts '*' * 100
            puts "*** started #{self.class}"
            puts

            super

            puts
            puts "*** ended #{self.class}"
            puts '*' * 100
        end
    end
    module FileStructure
        def create_directories
            puts _directory_exists? ? "... tried to create #{directory_path}, but it already exists" : "... creating directories #{directory_path}"
            super
        end
    end

    module HttpDownloader
        def run
            puts "... downloading #{config.address}"
            super
        end
    end

    module GbifTaxonImporter
        def run
            puts "... importing GBIF Taxonomy backbone"
            super
        end

        def _batch_import(columns, taxa)
            puts "... ... importing up to 100k records at once"
            super
        end
    end
end