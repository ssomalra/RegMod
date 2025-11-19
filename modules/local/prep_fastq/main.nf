process PREP_FASTQ {
	tag "$meta.id"
	label 'process_low'
	
	input:
	tuple val(meta), path(guppy) // directory containing 'pass' FASTQ files

	output:
	tuple val(meta), path("${meta.id}_${params.merged_output}.fastq"), emit: fastq
 	tuple val(meta), path("${meta.id}_${params.merged_output}.fasta"), emit: fasta

	script:
	"""
	# Merge FASTQ files from the 'pass' directory
	cat ${guppy}/pass/*.fastq > ${meta.id}_${params.merged_output}.fastq

	# Convert merged FASTQ to FASTA format
	sed -n '1~4s/^@/>/p;2~4p' ${meta.id}_${params.merged_output}.fastq > ${meta.id}_${params.merged_output}.fasta
        """
}
