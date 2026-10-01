process NANOPOLISH_POLYA {
	tag "$meta.id"
	label 'process_high'

	conda "bioconda::nanopolish=0.14.0"

	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/nanopolish:0.14.0--hee927d3_5' :
	'quay.io/biocontainers/nanopolish:0.14.0--hee927d3_5' }"

	input:
	tuple val(meta), path(guppy), path(fasta), path(fasta_index), path(sorted_bam), path(bai), path(reference_genome)

	output:
	tuple val(meta), path("${meta.id}_nanopolish_polya.tsv"), emit: nanopolish_polya
	path "versions.yml", emit: versions

	script:
	"""
	# rename the shared f5c index to match this chunk's fasta filename, since
	# nanopolish finds index files by filename convention next to --reads
	for idx in $fasta_index; do
		suffix=\${idx#*.fasta}
		ln -s "\$idx" "${fasta}\${suffix}"
	done

	# run nanopolish polya
	nanopolish polya --reads $fasta --bam=$sorted_bam --genome=$reference_genome --threads=2 > ${meta.id}_nanopolish_polya.tsv

	cat <<-END_VERSIONS > versions.yml
        "${task.process}":
                nanopolish: \$(nanopolish --version | head -n 1)
        END_VERSIONS
        """
}
