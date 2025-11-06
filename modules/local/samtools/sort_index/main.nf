process SAMTOOLS_SORT_INDEX {
	tag "$meta.id"
	label 'process_medium'

	clusterOptions="-A r00270 --job-name=SAMTOOLS_SORT_INDEX"

	conda "bioconda::samtools=1.21"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/samtools:1.21--h96c455f_1' :
	'quay.io/biocontainers/samtools:1.21--h96c455f_1' }"

	input:
	tuple val(meta), path(bam) 

	output:
	tuple val(meta), path("${meta.id}_${params.merged_output}.sorted.bam"), emit: sorted_bam
 	tuple val(meta), path("${meta.id}_${params.merged_output}.sorted.bam.bai"), emit: bai  
	path "versions.yml", emit: versions

	script:
	"""
	samtools sort $bam -o ${meta.id}_${params.merged_output}.sorted.bam
	samtools index -b ${meta.id}_${params.merged_output}.sorted.bam

	cat <<-END_VERSIONS > versions.yml
	"${task.process}":
 		samtools: \$(samtools --version | head -n 1)
    	END_VERSIONS
    	"""
}
