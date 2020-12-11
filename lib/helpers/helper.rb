# frozen_string_literal: true

class Helper
  include REXML

  def self.new_gbif_backbone_available?
    file                          = File.new("fm_data/GBIF_TAXONOMY/eml.xml")
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
  end
  
  def self.constantize(s)
      Object.const_get(s)
  end

  def self.generate_index_by_column_name(file:, separator:)
      column_names          = file.first.chomp.split(separator)
      num_columns           = column_names.size
      index_by_column_name  = Hash.new
      (0...num_columns).each do |index|
          index_by_column_name[column_names[index]] = index
      end
  
      return index_by_column_name
  end

  def self.extract_zip(name:, destination:, files_to_extract:)
      FileUtils.mkdir_p(destination)
    
      Zip::File.open(name) do |zip_file|
        zip_file.each do |f|
          next unless files_to_extract.include?(f.name)

          fpath = File.join(destination, f.name)
          zip_file.extract(f, fpath) unless File.exist?(fpath)
        end
      end
    end

    def self.create_marker_objects(query_marker_names:)
      return [] if query_marker_names.nil?
      marker_names = query_marker_names.split(',')
      marker_objects = []
      marker_names.each do |marker_name|
        marker = Marker.new(query_marker_name: marker_name)
        marker_objects.push(marker)
      end
      return marker_objects
    end

    def self.normalize(string)
      string.tr(
      "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
      "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
      )
    end

    def self.latinize_rank(rank)
      GbifTaxonomy.rank_mappings["#{rank}"]
    end
end