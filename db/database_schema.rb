# frozen_string_literal: true

class DatabaseSchema
	def self.create_db
		ActiveRecord::Schema.define do
			create_table :ncbi_ranked_lineages do |t|
				t.integer :tax_id, index: true
				t.string :name, index: true
				t.string :species
				t.string :genus
				t.string :familia
				t.string :ordo
				t.string :classis
				t.string :phylum
				t.string :regnum
				t.string :super_regnum

				t.timestamps
			end
			
			create_table :ncbi_names do |t|
				t.integer	:tax_id, index: true
				t.string 	:name, index: true
				t.string 	:unique_name
				t.string 	:name_class

				t.timestamps
			end
			
			create_table :ncbi_nodes do |t|
				t.integer 	:tax_id, index: true
				t.integer 	:parent_tax_id
				t.string 	:rank
				t.integer 	:division_id
				t.integer 	:genetic_code_id
				t.integer 	:mito_genetic_code_id
				t.boolean 	:has_specified_species
				t.integer 	:plastid_genetic_code_id

				t.timestamps
			end

			create_table :gbif_taxonomy do |t|
				t.integer :taxon_id, index: true
				t.string :dataset_id
				t.string :parent_name_usage_id, index: true
				t.string :accepted_name_usage_id, index: true
				t.string :original_name_usage_id
				t.string :scientific_name, index: true
				t.string :scientific_name_authorship, index: true # remove index
				t.string :canonical_name, index: true
				t.string :generic_name, index: true # remove index
				t.string :specific_epithet, index: true # remove index
				t.string :infraspecific_epithet, index: true # remove index
				t.string :taxon_rank # maybe index
				t.text :name_according_to
				t.text :name_published_in
				t.string :taxonomic_status # maybe index
				t.string :nomenclatural_status
				t.text :taxon_remarks
				t.string :regnum, index: true
				t.string :phylum, index: true
				t.string :classis, index: true
				t.string :ordo, index: true
				t.string :familia, index: true
				t.string :genus, index: true

				t.timestamps
			end
			
			create_table :gbif_homonyms, force: true do |t|
				t.integer 	:count
				t.integer 	:regnum_id
				t.string	:rank
				t.string	:canonical_name, index: true

				t.timestamps
			end
		end
	end
end
