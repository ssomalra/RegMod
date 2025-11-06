process ANNOTATE {
	tag "$meta.id"
	label 'process_low'

	clusterOptions = '--time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270 --job-name=ANNOTATE'
	beforeScript = 'module load python'

	input:
	tuple val(meta), path(nanopolish_polya)
	tuple val(meta), path(inference)
	tuple val(meta), path(gtf)

	output:
	tuple val(mtea), path("${meta.id}_nanopolish_annotated.tsv"), emit: annotated_polya
	tuple val(mtea), path("${meta.id}_m6A_annotated.tsv"), emit: annotated_m6A

	script:
	"""
	# run polyA annotation script
	python ${projectDir}/bin/polya_annotate.py \\
	   --input $nanopolish_polya \\
	   --gtf $gtf
	   --gtf_columns ${params.gtf_columns.join(" ")}

	# run m6A annotation script
	python ${projectDir}/bin/m6A_annotate.py \\
	   --input ${inference}/data.site_proba.csv \\
	   --gtf $gtf \\
           --gtf_columns ${params.gtf_columns.join(" ")}
    	""" 
}
