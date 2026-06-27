process F5C_INDEX {
	tag "$meta.id"
	label 'process_high'
	label 'gpu'

	beforeScript = 'module load python/gpu'

	conda "bioconda::f5c=1.5"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/f5c:1.5--hee927d3_2' :
        'quay.io/biocontainers/f5c:1.5--hee927d3_2' }"

	input:
	tuple val(meta), path(guppy)

	output:
	tuple val(meta), path("${meta.id}_${params.merged_output}.fasta"), emit: fasta
	tuple val(meta), path("*.index*"), emit: fasta_index
	path "versions.yml", emit: versions

	script:
	"""
	# Merge FASTQ files from the 'pass' directory
        cat ${guppy}/pass/*.fastq > ${meta.id}_${params.merged_output}.fastq

	# Convert merged FASTQ to FASTA format
        awk 'NR%4==1 {print ">" substr(\$0,2)}
	     NR%4==2 {print}' ${meta.id}_${params.merged_output}.fastq > ${meta.id}_${params.merged_output}.fasta

	# Index FASTA file
	f5c index -d ${guppy}/workspace/ ${meta.id}_${params.merged_output}.fasta

	cat <<-END_VERSIONS > versions.yml
	"${task.process}":
		f5c: \$(f5c --version | head -n 1)
	END_VERSIONS
	"""
}

