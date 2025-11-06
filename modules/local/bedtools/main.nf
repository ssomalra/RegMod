process BAM_TO_BED {
        tag "$meta.id"
        label 'process_low'

        clusterOptions = '--time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270 --job-name=BAM_TO_BED'

        conda "bioconda::bedtools=2.31.1"
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--h13024bc_3' :
        'quay.io/biocontainers/bedtools:2.31.1--h13024bc_3' }"

	input:
	tuple val(meta), path(sorted_bam)

	output:
	tuple val(meta), path("${meta.id}.bed"), emit: reads_bed
	path "versions.yml", emit: versions

	script:
	"""
	bedtools bamtobed -i $sorted_bam > ${meta.id}.bed

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
                bedtools: \$(bedtools --version | head -n 1)
        END_VERSIONS
        """
}
