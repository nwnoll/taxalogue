# frozen_string_literal: true

class Synonym
      attr_accessor     :accepted_taxon, :sources
      attr_reader       :synonyms

      def initialize(accepted_taxon:, sources:)
            @accepted_taxon   = accepted_taxon
            @sources          = sources
            @synonyms         = _get_synonyms
      end

      private
      def _get_synonyms
            return {} if sources.nil? || sources.empty? || sources.blank?
            return {} unless sources.size == 1 && sources.include?(GbifTaxonomy) || sources.include?(NcbiTaxonomy)
            return {} if accepted_taxon.nil?
            return {} if accepted_taxon.taxon_id.blank? || accepted_taxon.taxon_id.nil? 


            synonyms_of = Hash.new
            sources.each do |source|
                  synonyms_of[source] = source.where(accepted_name_usage_id: accepted_taxon.taxon_id) if source == GbifTaxonomy
                  synonyms_of[source] = source.where(tax_id: accepted_taxon.taxon_id) if source == NcbiTaxonomy
            end

            return synonyms_of
      end
end