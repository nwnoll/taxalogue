module Printing
    def self.job_run_start(class_name)
        puts '*' * 100
        puts "*** started #{class_name}"
        puts
    end

    def self.job_run_end(class_name)
        puts
        puts "*** ended #{class_name}"
        puts '*' * 100
    end

    def self.importer_message(class_name)
        class_to_import = class_name.to_s.gsub('Importer', '')
        puts "... importing #{class_to_import}"
    end

    def self.batch_import_message
        puts '... ... importing up to 100k records at once'
    end



    module GbifTaxonJob
        def run
            Printing.job_run_start(self.class)
            super
            Printing.job_run_end(self.class)
        end
    end

    module NcbiTaxonomyJob
        def run
            Printing.job_run_start(self.class)
            super
            Printing.job_run_end(self.class)
        end
    end



    module FileStructure
        def create_directory
            puts _directory_exists? ? "... tried to create #{directory_path}, but it already exists" : "... creating directory #{directory_path}"
            super
        end
    end

    module HttpDownloader
        def run
            puts "... downloading data for #{config.name}"
            puts "... at #{config.address}"
            puts
            super
        end
    end

    module GbifTaxonImporter
        def run
            Printing.importer_message(self.class)
            super
        end

        def _batch_import(columns, records)
            Printing.batch_import_message
            super
        end
    end

    module NcbiRankedLineageImporter
        def run
            Printing.importer_message(self.class)
            super
        end

        def _batch_import(columns, records)
            Printing.batch_import_message
            super
        end
    end

    module NcbiNodeImporter
        def run
            Printing.importer_message(self.class)
            super
        end

        def _batch_import(columns, records)
            Printing.batch_import_message
            super
        end
    end

    module NcbiNameImporter
        def run
            Printing.importer_message(self.class)
            super
        end

        def _batch_import(columns, records)
            Printing.batch_import_message
            super
        end
    end
end