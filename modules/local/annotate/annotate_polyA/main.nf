process ANNOTATE_POLYA {
        tag "$meta.id"
        label 'process_low'

        clusterOptions = '--time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270 --job-name=ANNOTATE_POLYA'

	conda "bioconda::pyranges=0.1.4"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/pyranges:0.1.2--pyhdfd78af_1' :
	'quay.io/biocontainers/pyranges:0.1.4--pyhdfd78af_0' }"

        input:
        tuple val(meta), path(polya_reads)
        tuple val(meta), path(gtf)

	output:
	tuple val(meta), path("${meta.id}_polyA_annotated.tsv"), emit: annotated_polya

	script:
	"""
	# run polyA annotation script
        python ${projectDir}/bin/polyA_annotate.py \
           --input $polya_reads \
           --gtf $gtf
	   --id $meta.id
        """
}
