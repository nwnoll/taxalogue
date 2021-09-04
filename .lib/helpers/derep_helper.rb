# frozen_string_literal: true

class DerepHelper

    def self.fill_specimens_of_sequence(specimens:, specimens_of_sequence:, taxonomic_info:, taxon_name:, first_specimen_info:)
        canonical_name = taxonomic_info.canonical_name
        # specimens_of_taxon[taxon_name][:data].each do |specimen|
        specimens.each do |specimen|
            seq = specimen[:sequence]
            if specimens_of_sequence.key?(seq)
                if specimens_of_sequence[seq].key?(canonical_name)
                    specimens_of_sequence[seq][canonical_name].specimens.push(specimen)
                else
                    seq_meta = OpenStruct.new(
                        taxonomic_infos: taxonomic_info,
                        first_specimen_infos: first_specimen_info,
                        source_taxon_name: taxon_name,
                        specimens: []
                    )
                    specimens_of_sequence[seq][canonical_name] = seq_meta

                    specimens_of_sequence[seq][canonical_name].specimens.push(specimen)
                end
            else
                info_per_canonical_name = Hash.new
                seq_meta = OpenStruct.new(
                    taxonomic_infos: taxonomic_info,
                    first_specimen_infos: first_specimen_info,
                    source_taxon_name: taxon_name,
                    specimens: []
                )
                info_per_canonical_name[canonical_name] = seq_meta

                info_per_canonical_name[canonical_name].specimens.push(specimen)
                specimens_of_sequence[seq] = info_per_canonical_name 
            end
        end
    end

    def self.dereplicate(specimens_of_sequence, taxonomy_params, query_taxon_name)
        seq_arys_to_import              = []
        top_arys_to_import              = []
        related_seqs_and_taxon_infos    = Hash.new
        already_pushed_tops             = Set.new

        specimens_of_sequence.each do |seq, seq_meta_of|
            seq_sha256_bubblebabble = Digest::SHA256.bubblebabble(seq)

            if Sequence.exists?(sha256_bubblebabble: seq_sha256_bubblebabble)
                sequence_ary_or_id = Sequence.find_by(sha256_bubblebabble: seq_sha256_bubblebabble).id
            else
                sequence_ary_or_id = [seq_sha256_bubblebabble, seq]
                seq_arys_to_import.push(sequence_ary_or_id)
            end

            seq_sha_or_id =  sequence_ary_or_id.kind_of?(Array) ? seq_sha256_bubblebabble : sequence_ary_or_id
            
            related_seqs_and_taxon_infos[seq_sha_or_id] = OpenStruct.new(
                taxon_object_proxy_sha_or_ids: [],
                specimens_nums: [],
                first_specimen_identifiers: [],
                first_specimen_locations: [],
                first_specimen_latitudes: [],
                first_specimen_longitudes: []
            )

            seq_meta_of.each do |canonical_name, seq_meta|
                if taxonomy_params[:ncbi]
                    used_taxonomy_string = 'ncbi'
                elsif taxonomy_params[:gbif_backbone]
                    used_taxonomy_string = 'gbif_backbone'
                elsif taxonomy_params[:gbif]
                    used_taxonomy_string = 'gbif'
                end
                
                taxon_object_proxy_string = "#{seq_meta.taxonomic_infos.regnum}|#{seq_meta.taxonomic_infos.phylum}|#{seq_meta.taxonomic_infos.classis}|#{seq_meta.taxonomic_infos.ordo}|#{seq_meta.taxonomic_infos.familia}|#{seq_meta.taxonomic_infos.genus}|#{seq_meta.taxonomic_infos.canonical_name}|#{seq_meta.taxonomic_infos.scientific_name}|#{used_taxonomy_string}"
                taxon_object_proxy_string_as_sha256_bubblebabble = Digest::SHA256.bubblebabble(taxon_object_proxy_string)
                
                if TaxonObjectProxy.exists?(sha256_bubblebabble: taxon_object_proxy_string_as_sha256_bubblebabble)
                    taxon_object_proxy_ary_or_id = TaxonObjectProxy.find_by(sha256_bubblebabble: taxon_object_proxy_string_as_sha256_bubblebabble).id
                elsif already_pushed_tops.include?(taxon_object_proxy_string_as_sha256_bubblebabble)
                    ## lateron I check if the variable is of kind array
                    # if thats the case i will use the sha
                    # i have to use the sha since I dont yet have the ID, because
                    # I import all at once later
                    taxon_object_proxy_ary_or_id = [] 
                else
                    seq_meta_hash = seq_meta.taxonomic_infos.as_json
                    ## TODO:
                    ## fix synonyms
                    ## fix derep for gbif
                    ## write more tests
                    # byebug
                    seq_meta_hash[:combined] = seq_meta_hash[:combined].join(', ') if seq_meta_hash[:combined]

                    taxon_object_proxy_ary_or_id = seq_meta_hash.values
                    taxon_object_proxy_columns = TaxonObjectProxy.column_names -["id", "created_at", "updated_at"]
                    taxon_object_proxy_column_names.each do |column_name|
                        seq_meta_hash.key?(column_name)
                    end
                    
                    taxon_object_proxy_ary_or_id.push(query_taxon_name, used_taxonomy_string, taxonomy_params[:synonyms_allowed], seq_meta.source_taxon_name, taxon_object_proxy_string_as_sha256_bubblebabble)
                    top_arys_to_import.push(taxon_object_proxy_ary_or_id)
                    already_pushed_tops.add(taxon_object_proxy_string_as_sha256_bubblebabble)
                end

                top_sha_or_id =  taxon_object_proxy_ary_or_id.kind_of?(Array) ? taxon_object_proxy_string_as_sha256_bubblebabble : taxon_object_proxy_ary_or_id
                related_seqs_and_taxon_infos[seq_sha_or_id].taxon_object_proxy_sha_or_ids.push(top_sha_or_id)
                related_seqs_and_taxon_infos[seq_sha_or_id].specimens_nums.push(seq_meta.specimens.size)
                related_seqs_and_taxon_infos[seq_sha_or_id].first_specimen_identifiers.push(seq_meta.specimens.first[:identifier])
                related_seqs_and_taxon_infos[seq_sha_or_id].first_specimen_locations.push(seq_meta.specimens.first[:location])
                related_seqs_and_taxon_infos[seq_sha_or_id].first_specimen_latitudes.push(seq_meta.specimens.first[:latitude])
                related_seqs_and_taxon_infos[seq_sha_or_id].first_specimen_longitudes.push(seq_meta.specimens.first[:longitude])
            end

        end

        seq_columns     = Sequence.column_names - ['id']
        top_columns     = TaxonObjectProxy.column_names - ['id']
        seq_top_columns = SequenceTaxonObjectProxy.column_names - ['id']
        
        TaxonObjectProxy.import top_columns, top_arys_to_import, validate: false, batch_size: 100_000 if top_arys_to_import.any?
        Sequence.import seq_columns, seq_arys_to_import, validate: false, batch_size: 100_000 if seq_arys_to_import.any?
        sleep 1

        seq_top_arys_to_import = []
        related_seqs_and_taxon_infos.each do |key, value|
            seq_id = key.kind_of?(String) ? Sequence.find_by(sha256_bubblebabble: key).id : key
            value.taxon_object_proxy_sha_or_ids.each_with_index do |top_sha_or_id, index|
                top_id = top_sha_or_id.kind_of?(String) ? TaxonObjectProxy.find_by(sha256_bubblebabble: top_sha_or_id).id : top_sha_or_id
                
                unless SequenceTaxonObjectProxy.exists?(sequence_id: seq_id, taxon_object_proxy_id: top_id)
                    seq_top_arys_to_import.push([seq_id, top_id, value.specimens_nums[index], value.first_specimen_identifiers[index], value.first_specimen_locations[index], value.first_specimen_latitudes[index], value.first_specimen_longitudes[index]])
                end

                $seq_ids.push(seq_id)
            end
        end

        SequenceTaxonObjectProxy.import seq_top_columns, seq_top_arys_to_import, validate: false, batch_size: 100_000 if seq_top_arys_to_import.any?
        sleep 1
    end
end