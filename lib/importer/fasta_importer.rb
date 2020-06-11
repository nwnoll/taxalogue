# frozen_string_literal: true

class FastaImporter

	Seq = Struct.new(:header, :nuc_seq, :prot_seq)

	def self.import(file_name)

		file = File.open(file_name, "r")

		seq_of = Hash.new
		header = ''
		fasta_records = []
		file.each do |line|
		  line.chomp!
		  if line =~ /^>/
		  	fasta_records.push((Seq.new(header, seq_of[header], to_aa_seq(seq_of[header])).to_a)) unless header == ''
		    header = line
		  else
		  	seq_of.key?(header) ? seq_of[header] << line : seq_of[header] = line
		  end
		end
		## since we add the translated sequence after we have to it one time again for the last item
		fasta_records.push((Seq.new(header, seq_of[header], to_aa_seq(seq_of[header]))).to_a)

		columns = [:header, :nuc_seq, :prot_seq]
		FastaRecord.import columns, fasta_records, validates: false
	end

	private
	def self.to_aa_seq(val)
		# TLYFIFGIWAGMVGTSLSLLIRAELGNPGSLIGDDQIYNTIVTAHAFIMIFFMVMPIMIGGFGNWLIPLMLGAPDMAFPRMNNMSFWLLPPSLTLLISSSIVENGAGTGWTVYP
		# consensus_seq = 'PLSSNIAHGGSSVDLAIFSLHLAGISSILGAINFITTIINMRLNSMSFDQMPLFVWAVGITAFLLLLSLPVLAGAITMLLTDRNLNTSFFDPAGGGDPILYQHLF'
		# consensus_seq = 'TLYFIFGIWAGMVGTSLSLLIRAELGNPGSLIGDDQIYNTIVTAHAFIMIFFMVMPIMIGGFGNWLIPLMLGAPDMAFPRMNNMSFWLLPPSLTLLISSSIVENGAGTGWTVYPPLSSNIAHGGSSVDLAIFSLHLAGISSILGAINFITTIINMRLNSMSFDQMPLFVWAVGITAFLLLLSLPVLAGAITMLLTDRNLNTSFFDPAGGGDPILYQHLF'

		# >AEN56219.1 cytochrome oxidase subunit 1, partial (mitochondrion) [Aeshna sp. BBODA277-10]
		# TLYFLFGAWSGMVGTALSVLIRIELGQPGSLIGDDQIYNVIVTAHAFVMIFFMVMPIMIGGFGNWLVPLM
		# LGAPDMAFPRLNNMSFWLLPPSLTLLLAGSMVESGAGTGWTVYPPLAGAIAHAGASVDLTIFSLHLAGVS
		# SILGAINFITTTINMKSPGMKMDQMPLFVWAVVITAVLLLLSLPVLAGAITMLLTDRNINTSFFDPAGGG
		# DPILYQHLF
		consensus_seq = "TLYFLFGAWSGMVGTALSVLIRIELGQPGSLIGDDQIYNVIVTAHAFVMIFFMVMPIMIGGFGNWLVPLMLGAPDMAFPRLNNMSFWLLPPSLTLLLAGSMVESGAGTGWTVYPPLAGAIAHAGASVDLTIFSLHLAGVSSILGAINFITTTINMKSPGMKMDQMPLFVWAVVITAVLLLLSLPVLAGAITMLLTDRNINTSFFDPAGGGDPILYQHLF"
		nuc_seq = Bio::Sequence::NA.new(val)
		seq_and_distance = []
		(1..6).each do |frame|
		    prot_seq        = nuc_seq.translate(frame, 5, '$')
		    num_stop_codons = prot_seq.scan(/\*/).count
		    jarow = FuzzyStringMatch::JaroWinkler.create(:native)
		    distance_to_consensus = jarow.getDistance(prot_seq, consensus_seq)
		    # puts "#{prot_seq} #{num_stop_codons} #{distance_to_consensus}"
		    seq_and_distance = [prot_seq, distance_to_consensus, frame] if seq_and_distance.length == 0 || distance_to_consensus > seq_and_distance[1]
		end
		seq_and_distance[0]
	end

end
