process ANNOTATE_M6A {
        tag "$meta.id"
        label 'process_low'

        clusterOptions = '--time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270 --job-name=ANNOTATE_M6A'

	conda "bioconda::pyranges=0.1.4"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/pyranges:0.1.2--pyhdfd78af_1' :
	'quay.io/biocontainers/pyranges:0.1.4--pyhdfd78af_0' }"

        input:
        tuple val(meta), path(m6A_coordinates)
        tuple val(meta), path(gtf)

	output:
	tuple val(meta), path("${meta.id}_m6A_annotated.tsv"), emit: annotated_m6A

	script:
	"""
	# run m6A annotation script
        python ${projectDir}/bin/m6A_annotate.py \
           --input $m6A_coordinates \
           --gtf $gtf
	   --id $id
	"""
}
