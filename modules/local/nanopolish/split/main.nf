process SPLIT_NANOPOLISH_FASTA {
	tag "$meta.id"
	label 'cpu'

	input:
	tuple val(meta), path(fasta)

	output:
	tuple val(meta), path("${meta.id}_chunk*.fasta", arity: '1..*'), emit: chunks

	script:
	"""
	# round-robin split reads into ${params.nanopolish_chunks} chunks while preserving FASTA records
	awk -v n=${params.nanopolish_chunks} -v p="${meta.id}" '
		/^>/ { out = p "_chunk" (c++ % n) ".fasta" }
		out != "" && NF { print > out }
	' $fasta
	"""
}
