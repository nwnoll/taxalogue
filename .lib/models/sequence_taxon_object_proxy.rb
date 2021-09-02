# frozen_string_literal: true

class SequenceTaxonObjectProxy < ActiveRecord::Base
    belongs_to :sequence
    belongs_to :taxon_object_proxy
end
