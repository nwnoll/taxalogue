# frozen_string_literal: true

class Sequence < ActiveRecord::Base
    has_many :specimen_metas
    has_many :taxon_object_proxies
end
