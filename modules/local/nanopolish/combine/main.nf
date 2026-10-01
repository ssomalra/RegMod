process COMBINE_NANOPOLISH_POLYA {
	tag "$meta.id"
	label 'cpu'

	input:
	tuple val(meta), path(polya_tsvs)

	output:
	tuple val(meta), path("${meta.id}_nanopolish_polya.tsv"), emit: nanopolish_polya

	script:
	"""
	# concatenate per-chunk nanopolish polya outputs, keeping only the first header line
	awk 'FNR==1 && NR!=1 {next} {print}' ${polya_tsvs.join(' ')} > ${meta.id}_nanopolish_polya.tsv
	"""
}
