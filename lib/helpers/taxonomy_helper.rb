# frozen_string_literal: true

class TaxonomyHelper
    include REXML

    def self.new_ncbi_taxonomy_available?
        ncbi_taxonomy_update_config_name = 'lib/configs/ncbi_taxonomy_update_config.json' 
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
end