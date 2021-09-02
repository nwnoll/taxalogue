# frozen_string_literal: true

class Sequence < ActiveRecord::Base
    has_many :sequence_taxon_object_proxies
    has_many :taxon_object_proxies, through: :sequence_taxon_object_proxies

    def tops_with_extra_info
        self.taxon_object_proxies.includes(:sequence_taxon_object_proxies)
    end
end
