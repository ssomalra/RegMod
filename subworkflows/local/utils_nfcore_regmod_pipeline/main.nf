//
// Subworkflow with functionality specific to the nf-core/regmod pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

import java.io.File

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    //
    // Create channel from input file provided through params.input
    //
    Channel
        Channel.fromList(samplesheetToList(params.input, "assets/schema_input.json"))
        .map { meta, condition, replicate, fast5_dir, flowcell_id, sequencing_kit, reference_genome, gtf ->
	    return [meta, condition, replicate, fast5_dir, flowcell_id, sequencing_kit, reference_genome, gtf]
        }
	.view()
        .map { samplesheet ->
            validateInputSamplesheet(samplesheet)
        }
	.view()
		.set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                []
            )
        }

        completionSummary(monochrome_logs)
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (meta, condition, replicate, fast5_dir, flowcell_id, sequencing_kit, reference_genome, gtf) = input[0..7]
       
    // Validate that fast5_dir exists and contains valid .fast5 files
    def fast5Directory = new File(fast5_dir.toString())
    if (!fast5Directory.exists() || !fast5Directory.isDirectory()) {
	error("Please check input samplesheet -> The directory specified for FAST5 files does not exist or is not a valid directory: ${fast5_dir}")
    }

    def fast5Files = fast5Directory.listFiles({dir, name -> name.endsWith('.fast5') } as FilenameFilter)
    if (fast5Files.length == 0) {
	error("Please check input samplesheet -> No FAST5 files found in the directory: ${fast5_dir}")
    }

    def emptyFiles = fast5Files.findAll {it.length() == 0}
    if (!emptyFiles.isEmpty()) {
	error("Please check input samplesheet -> The following FAST5 files are empty: ${emptyFiles*.name.join('\n')}")
    }
 
    // Validate that the reference genome is provided
    if (!reference_genome) {
        error("Please check input samplesheet -> Reference genome must be provided for all samples.")
    }

    // Validate that the GTF file is provided
    if (!gtf) {
        error("Please check input samplesheet -> A GTF file must be provided for all samples.")
    }

    // Validate that the flowcell_id and sequencing_kit are provided
    if (!flowcell_id || !sequencing_kit) {
	error("Please check input samplesheet -> Flowcell ID and sequencing kit must be specified for basecalling.")
    }

    return [meta, condition, replicate, fast5_dir, flowcell_id, sequencing_kit, reference_genome, gtf]
}

def validateInputParameters() {
    if (!params.input || params.input == '' || !file(params.input).exists()) {
        error("Input file '${params.input}' not found. Please provide a valid samplesheet.")
    }

    if (!params.guppy_package || params.guppy_package == 'path/to/ont-guppy-cpu') {
        error("Guppy path is not set. Update 'guppy_package' in your config file.")
    }
}
