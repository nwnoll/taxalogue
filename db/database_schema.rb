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

            create_table :sequences do |t|
                t.string    :sha256_bubblebabble, index: true
                t.text      :zlib_deflated
                t.string    :marker

                t.timestamps
            end

            create_table :specimen_metas do |t|
                t.string        :identifier, index: true
                t.string        :source_taxon_name, index: true
                t.string        :location
                t.string        :lat
                t.string        :long

                t.references    :sequence

                t.timestamps
            end
		end
	end

    def self.migrate
        ## if I want to add some table i will put it here 
        ## and in create and delete it afterwards in this migration

        ActiveRecord::Schema.define do

            create_table :sequences do |t|
                t.string    :sha256_bubblebabble, index: true
                t.text      :nucleotides

                t.timestamps
            end

            create_table :taxon_object_proxies do |t|
				t.integer :taxon_id
				t.string :regnum
				t.string :phylum
				t.string :classis
				t.string :ordo
				t.string :familia
				t.string :genus
				t.string :canonical_name, index: true
				t.string :scientific_name
				t.string :taxonomic_status
				t.string :taxon_rank
				t.string :combined
				t.string :comment
				t.string :query_taxon_name
				t.string :used_taxonomy
				t.boolean :synonyms_allowed
				t.string :source_taxon_name, index: true
				t.string :sha256_bubblebabble, index: true

				t.timestamps
			end

            create_table :sequence_taxon_object_proxies do |t|
                t.belongs_to :sequence
                t.belongs_to :taxon_object_proxy
                t.integer :specimens_num
                t.string :first_specimen_identifier

                t.timestamps
            end

            # create_table :specimen_metas do |t|
            #     t.string        :identifier
			# 	  t.string        :sha256_bubblebabble, index: true
            #     t.string        :source_taxon_name
            #     t.string        :location
            #     t.string        :lat
            #     t.string        :long
            #     t.string        :used_source_database

            #     t.references    :sequence
            #     t.references    :taxon_object_proxy

            #     t.timestamps
            # end
        end
    end

    def self.drop(table_name)
        ActiveRecord::Schema.verbose = false
        ActiveRecord::Migration.drop_table(table_name)
    end

    def self.create_table(table_name)
        ActiveRecord::Schema.verbose = false
        if table_name == :sequence_taxon_object_proxies
            ActiveRecord::Schema.define do
                create_table :sequence_taxon_object_proxies do |t|
                    t.belongs_to :sequence
                    t.belongs_to :taxon_object_proxy
                    t.integer :specimens_num
                    t.string :first_specimen_identifier
                    t.string :first_specimen_location
                    t.string :first_specimen_latitude
                    t.string :first_specimen_longitude

                    t.timestamps
                end
            end
        end
    end
end
