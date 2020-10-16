# frozen_string_literal: true

class Synonym
      attr_accessor     :accepted_taxon, :nomial, :specimen, :sources
      attr_reader       :synonyms

      private
      def _get_synonyms
            return [] if sources.nil? || sources.empty? || sources.blank?
            ## for now only the GbifTaxonomy backbone will be searched,
            ## later on also synonyms from NcbiTaxonomy and ITIS will be implemented
            return [] unless sources.size == 1 && sources.include?(GbifTaxon)
            return [] if accepted_taxon.nil?
            return [] if accepted_taxon.taxon_id.blank?


            synonyms_of = Hash.new
            sources.each do |source|
                  synonyms_of[source] = source.where(accepted_name_usage_id: accepted_taxon.taxon_id)
            end
      end
end