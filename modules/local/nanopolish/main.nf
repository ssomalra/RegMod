process NANOPOLISH_POLYA {
	tag "$meta.id"
	label "process_high"

	clusterOptions = '--partition=gpu --gpus=1 --time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270 --job-name=NANOPOLISH_POLYA'
	beforeScript = 'module load python/gpu'

	conda "bioconda::nanopolish=0.14.0"

	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/nanopolish:0.14.0--hee927d3_5' :
	'quay.io/biocontainers/nanopolish:0.14.0--hee927d3_5' }"

	input:
	tuple val(meta), path(reference_genome)
	tuple val(meta), path(fasta)
	tuple val(meta), path(fasta_index)
	tuple val(meta), path(guppy)
	tuple val(meta), path(sorted_bam)
	tuple val(meta), path(bai)
	tuple val(meta), path(reads_bed)

	output:
	tuple val(meta), path("${meta.id}_nanopolish_polya.tsv"), emit: nanopolish_polya
	tuple val(meta), path("${meta.id}_polyA.bed"), emit: polya_reads
	path "versions.yml", emit: versions

	script:
	"""
	# run nanopolish polya
	nanopolish polya --reads $fasta --bam=$sorted_bam --genome=$reference_genome > ${meta.id}_nanopolish_polya.tsv

        # filter nanopolish results to PASS only
        awk '\\$NF == "PASS"' $nanopolish_polya > nanopolish_polya_filtered.tsv

        # add polyA tail length from nanopolish to the end of the BED file
        awk -F'\\t' 'FNR==NR {a[\$1]=\$9; next} \$4 in a {print \$0 "\\t" a[\$4]}' nanopolish_polya_filtered.tsv $reads_bed > ${meta.id}_polyA.bed

	cat <<-END_VERSIONS > versions.yml
        "${task.process}":
                nanopolish: \$(nanopolish --version | head -n 1)
        END_VERSIONS
        """
}
