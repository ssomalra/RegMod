process SAMTOOLS_INDEX {
	tag "$meta.id"
	label 'process_low'

	clusterOptions="-A r00270 --job-name=SAMTOOLS_INDEX"

	conda "bioconda::samtools=1.21"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1' :
	'quay.io/biocontainers/samtools:1.21--h96c455f_1' }"

	input:
	tuple val(meta), path(sorted_bam) 

	output:
	tuple val(meta), path("*.bai"), emit: bai 
	path "versions.yml", emit: versions

	script:
	"""
	samtools index -b $sorted_bam

	cat <<-END_VERSIONS > versions.yml
	"${task.process}":
 		samtools: \$(samtools --version | head -n 1)
    	END_VERSIONS
    	"""
}
