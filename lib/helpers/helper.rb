# frozen_string_literal: true

class Helper
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

  def self.extract_zip(file:, destination:)
      FileUtils.mkdir_p(destination)
    
      Zip::File.open(file) do |zip_file|
        zip_file.each do |f|
          fpath = File.join(destination, f.name)
          zip_file.extract(f, fpath) unless File.exist?(fpath)
        end
      end
    end

    def self.create_marker_objects(query_marker_names:)
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
      GbifTaxon.rank_mappings["#{rank}"]
    end
end