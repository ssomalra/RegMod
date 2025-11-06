process F5C_INDEX {
	tag "$meta.id"
	label 'process_high'

	clusterOptions = '--partition=gpu --gpus=1 --time=1-23:59:00 --mail-user=ssomalra@iu.edu --mail-type=BEGIN,END,FAIL --account=r00270'
	beforeScript = 'module load python/gpu; module load apptainer'

	conda "bioconda::f5c=1.5"
	container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/f5c:1.5--hee927d3_2' :
        'quay.io/biocontainers/f5c:1.5--hee927d3_2' }"

	input:
	tuple val(meta), path(guppy)
        tuple val(meta), path(fasta)

	output:
	tuple val(meta), path("*.index*"), emit: fasta_index
	path "versions.yml", emit: versions

	script:
	"""
	f5c index -d ${guppy}/workspace/ $fasta

	cat <<-END_VERSIONS > versions.yml
	"${task.process}":
		f5c: \$(f5c --version | head -n 1)
	END_VERSIONS
	"""
}

