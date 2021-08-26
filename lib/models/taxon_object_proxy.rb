# frozen_string_literal: true

class TaxonObjectProxy < ActiveRecord::Base
    belongs_to :sequence
end
