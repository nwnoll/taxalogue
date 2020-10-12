# frozen_string_literal: true

class GbifHomonym < ActiveRecord::Base

      def self.possible_ranks
            GbifHomonym.all.pluck(:rank).uniq
      end
end
