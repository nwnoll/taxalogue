# frozen_string_literal: true

class TaxonomyHelper
    include REXML

    def self.new_ncbi_taxonomy_available?
        ncbi_taxonomy_update_config_name = '.lib/configs/ncbi_taxonomy_update_config.json' 
        params = MiscHelper.json_file_to_hash(ncbi_taxonomy_update_config_name)
        config = Config.new(params)
        
        downloader = HttpDownloader2.new(address: config.address, destination: config.file_manager.file_path)
        downloader.run
    
        unless File.exists?('downloads/NCBI_TAXONOMY/NCBI_TAXONOMY.zip')
            puts "The NCBI Taxonomy has not been setup yet, please use setup --ncbi_taxonomy"
            
            return true
        end
    
        md5_sum_download    = Digest::MD5.hexdigest(File.read('downloads/NCBI_TAXONOMY/NCBI_TAXONOMY.zip'))
        check_file          = File.read(config.file_manager.file_path)
        check_file          =~ /^(.*?)\s/
        md5_sum_check_file  = $1
    
        if md5_sum_download == md5_sum_check_file
            return false
        else
            return true
        end
    end

    def self.new_gbif_taxonomy_available?

        unless File.exists?('downloads/GBIF_TAXONOMY/eml.xml') || File.exists?('downloads/GBIF_TAXONOMY/Taxon.tsv')
            puts "The GBIF Taxonomy has not been setup yet, please use setup --gbif_taxonomy"
            return true
        end
    
    
        file                          = File.new("downloads/GBIF_TAXONOMY/eml.xml")
        doc                           = Document.new(file)
        timestamp_local_gbif_backbone = doc.get_elements('//dateStamp').first.to_s
        timestamp_local_gbif_backbone =~ />(.*?)</
        timestamp_local_gbif_backbone = $1
    
        gbif_backbone_dataset         = GbifApi.new(path: 'dataset/', query: 'd7dddbf4-2cf0-4f39-9b2a-bb099caae36c')
        gbif_backbone_modified_at 	  = gbif_backbone_dataset.response_hash['modified']
        
        return false if timestamp_local_gbif_backbone.nil? || gbif_backbone_modified_at.nil?
        
        datetime_local                = DateTime.parse(timestamp_local_gbif_backbone ,"%Y-%m-%dT%H:%M:%S")
        datetime_remote               = DateTime.parse(gbif_backbone_modified_at,     "%Y-%m-%dT%H:%M:%S")
    
        if datetime_remote > datetime_local
            return true
        else
            return false
        end
    end

    def self.setup_taxonomy
        gbif_taxonomy_job 	= GbifTaxonomyJob.new
        ncbi_taxonomy_job 	= NcbiTaxonomyJob.new
      
        multiple_jobs 		= MultipleJobs.new(jobs: [gbif_taxonomy_job, ncbi_taxonomy_job])
        multiple_jobs.run
    
        GbifHomonymImporter.new(file_name: 'homonyms.txt').run
    end

    def self.latinize_rank(rank)
        GbifTaxonomy.rank_mappings["#{rank}"]
    end

    def self.get_source_db(taxonomy_params)
        if taxonomy_params[:gbif] || taxonomy_params[:gbif_backbone]
            return GbifTaxonomy
        elsif taxonomy_params[:ncbi]
            return NcbiTaxonomy
        else
            return NcbiTaxonomy
        end
    end

    def self.download_predefined_database
        if File.file?('.db/database.db')

            MiscHelper.OUT_question("A database file already exists. Do you really want to overwrite it? [Y/n]")
            user_input = gets.chomp
            overwrite_db = (user_input =~ /y|yes/i) ? true : false
            
            return :database_already_exists unless overwrite_db
        end
        
        MiscHelper.OUT_header('Downloading Taxonomy databases')
        puts

        downloader = HttpDownloader2.new(address: 'https://drive.google.com/file/d/1L-9TqV9KGMQMLrNXSC7oy9z9FxrCOU6X/view?usp=sharing', destination: '.db/database.db.gz' )
        downloader.run

        downloader2 = HttpDownloader2.new(address: 'https://drive.google.com/file/d/10lRl82GdVtHGRNhDCryzIJ50KS4J5HM8/view?usp=sharing', destination: '.db/md5sum.txt' )
        downloader2.run
        sleep 2
        puts 'Download finished'
        puts

        unless File.file?('.db/database.db.gz') && File.file?('.db/md5sum.txt')
            MiscHelper.OUT_error('Cant find downloaded files, please download again')
            puts
            
            return :no_download_files 
        end

        MiscHelper.OUT_header('Extracting the database')
        puts

        begin
            Zlib::GzipReader.open('.db/database.db.gz') do | input_stream |
                File.open('.db/database.db', 'w') do |output_stream|
                    IO.copy_stream(input_stream, output_stream)
                end
            end
        rescue => e
            p e
            MiscHelper.OUT_error("Could not extract the database, please download again")
            puts
            
            return :cant_extract
        end
        puts 'Extraction finished'
        puts

        unless File.file?('.db/database.db') && File.file?('.db/md5sum.txt')
            MiscHelper.OUT_error('Cant find extracted files, please download again')
            
            return :no_extracted_files 
        end

        MiscHelper.OUT_header('Checking the integrity of the database')
        puts

        md5_sum_download    = Digest::MD5.hexdigest(File.read('.db/database.db'))
        check_file          = File.read('.db/md5sum.txt')
        check_file          =~ /^(.*?)\s/
        md5_sum_check_file  = $1
    
        unless md5_sum_download == md5_sum_check_file
            MiscHelper.OUT_error('Database file is corrupted, please download again.')
            puts
            return :different_md5_sum
        end
        puts 'Database file is OK'
        puts

        MiscHelper.OUT_success('Successfully downloaded the predefined taxonomy database')
        puts
        
        return :success
    end
end