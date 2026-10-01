process XPORE_DIFFMOD {
    label "process_medium"
    label "cpu"

    conda "bioconda::xpore==2.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
	'https://depot.galaxyproject.org/singularity/xpore:2.2--pyh106432d_0' :
	'quay.io/biocontainers/xpore:2.2--pyh106432d_0' }"

    publishDir "${params.outdir}/xpore/diffmod", mode: 'copy'

    input:
    path(xpore_model)
    val(xpore_samples)

    output:
    path("diffmod.table")
    path("diffmod.log")
    path("models")
    path("config.yml")

    script:

    def sample_args = xpore_samples.collect { sample ->
        "--samples ${sample.condition} ${sample.replicate} ${sample.dataprep_dir}"
    }.join(" \\\n    ")

    """
    python ${projectDir}/bin/generate_xpore_config.py \
        ${sample_args} \
        --output config.yml \
        --prior ${xpore_model}
    
    xpore diffmod \
        --config config.yml \
        --n_processes ${params.xpore_processes} \
    """
}
