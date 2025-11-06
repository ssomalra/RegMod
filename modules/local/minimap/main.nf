process MINIMAP2_ALIGN {
	tag "$meta.id"
	label 'process_high'

	clusterOptions = '--time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270'

	conda "bioconda::minimap2=2.17"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.17--hed695b0_3' :
        'quay.io/biocontainers/minimap2:2.17--hed695b0_3' }"

	input:
	tuple val(meta), path(reference_genome)
	tuple val(meta), path(fasta)

	output:
	tuple val(meta), path("${meta.id}_${params.merged_output}.sam"), emit: sam
	path "versions.yml", emit: versions
	
	script:
	"""
    	minimap2 --secondary=no -a -x map-ont $reference_genome $fasta > ${meta.id}_${params.merged_output}.sam

    	cat <<-END_VERSIONS > versions.yml
    	"${task.process}":
        	minimap2: \$(minimap2 --version 2>&1)
    	END_VERSIONS
    	"""	
}
