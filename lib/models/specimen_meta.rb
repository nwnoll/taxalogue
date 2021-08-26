# frozen_string_literal: true

class SpecimenMeta < ActiveRecord::Base
    self.table_name = 'specimen_metas'

    belongs_to :sequence
    belongs_to :taxon_object_proxy, optional: true
end
