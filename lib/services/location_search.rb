# frozen_string_literal: true

class LocationSearch

    def self.by_name(name)
        ISO3166::Country.find_country_by_name(name)
    end

    def self.by_region(region)
        ISO3166::Country.find_all_countries_by_region(region)
    end
end