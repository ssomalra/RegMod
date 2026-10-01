process XPORE_DATAPREP {
    tag "$meta.id"
    label "process_medium"
    label "cpu"

    conda "bioconda::xpore==2.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/xpore:2.2--pyh106432d_0' :
	'quay.io/biocontainers/xpore:2.2--pyh106432d_0' }"

    input:
    tuple val(meta), path(eventalign_output)

    output:
    tuple val(meta), path("${meta.id}_xpore_dataprep"), emit: xpore_dataprep

    script:
    """
    xpore dataprep \
        --eventalign $eventalign_output \
        --out_dir ${meta.id}_xpore_dataprep \
        --n_processes ${params.xpore_processes}

    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            xPore: \$(xpore --version | head -n 1)
        END_VERSIONS
    """
}
