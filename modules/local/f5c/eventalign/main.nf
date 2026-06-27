process F5C_EVENTALIGN {
	tag "$meta.id"
	label 'process_high'
	label 'gpu'

	beforeScript = 'module load python/gpu'

	conda "bioconda::f5c=1.5"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/f5c:1.5--hee927d3_2' :
        'quay.io/biocontainers/f5c:1.5--hee927d3_2' }"

	input:
	tuple val(meta), path(guppy), path(fasta), path(fasta_index), path(sorted_bam), path(bai), path(reference_genome)

	output:
	tuple val(meta), path("${meta.id}_eventalign.txt"), emit: eventalign_output
	path "versions.yml", emit: versions

	script:
	"""
	f5c eventalign -r $fasta -b $sorted_bam -g $reference_genome --rna --signal-index --scale-events > ${meta.id}_eventalign.txt

	cat <<-END_VERSIONS > versions.yml
	"${task.process}":
		f5c: \$(f5c --version | head -n 1)
	END_VERSIONS
	"""
}

