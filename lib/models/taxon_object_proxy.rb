# frozen_string_literal: true

class TaxonObjectProxy < ActiveRecord::Base
    has_many :sequence_taxon_object_proxies
    has_many :sequences, through: :sequence_taxon_object_proxies


    def seqs_with_extra_info
        self.sequences.includes(:sequence_taxon_object_proxies)
    end
end
