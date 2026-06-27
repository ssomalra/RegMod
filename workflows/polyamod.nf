/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { GUPPY_BASECALL         } from '../modules/local/guppy/main.nf'   
include { F5C_INDEX              } from '../modules/local/f5c/index/main.nf'
include { MINIMAP2_ALIGN         } from '../modules/local/minimap/main.nf'
include { SAMTOOLS               } from '../modules/local/samtools/main.nf'
include { NANOPOLISH_POLYA 	 } from '../modules/local/nanopolish/main.nf'
include { ANNOTATE_POLYA         } from '../modules/local/annotate/annotate_polyA/main.nf'
include { F5C_EVENTALIGN	 } from '../modules/local/f5c/eventalign/main.nf'
include { M6ANET		 } from '../modules/local/m6anet/main.nf'
include { ANNOTATE_M6A		 } from '../modules/local/annotate/annotate_m6A/main.nf'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow POLYAMOD {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    
    main:
    ch_versions = Channel.empty()

    // Define shared channels
    ch_reference = ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,reference_genome)}
    ch_gtf = ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,gtf)}

    //
    // MODULE: Run Guppy
    // 
    GUPPY_BASECALL (
	ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,fast5_dir,flowcell_id,sequencing_kit)}
    )

    //
    // MODULE: Convert fasta > fastq and run f5c index
    //
    F5C_INDEX (
	GUPPY_BASECALL.out.guppy
    )

    //
    // MODULE: Run minimap2 
    //
    ch_minimap_input = F5C_INDEX.out.fasta
	.join(ch_reference)

    MINIMAP2_ALIGN (
	ch_minimap_input
    )

    //
    // MODULE: Samtools flagstat, view, sort, and index
    // 
    SAMTOOLS (
	MINIMAP2_ALIGN.out.sam
    )

    //
    // MODULE: Run nanopolish poly(A)
    //
    ch_nanopolish_input = GUPPY_BASECALL.out.guppy
	.join(F5C_INDEX.out.fasta)
        .join(F5C_INDEX.out.fasta_index)
        .join(SAMTOOLS.out.sorted_bam)
        .join(SAMTOOLS.out.bai)
        .join(ch_reference)

    NANOPOLISH_POLYA (
	ch_nanopolish_input
    )

    //
    // MODULE: Run polyA annotation python file
    //
    ch_annotate_polya_input = NANOPOLISH_POLYA.out.nanopolish_polya
          .join(ch_gtf)

    ANNOTATE_POLYA (
        ch_annotate_polya_input
    )

    //
    // MODULE: Run f5c eventalign
    // 
    ch_eventalign_input = GUPPY_BASECALL.out.guppy
	.join(F5C_INDEX.out.fasta)
	.join(F5C_INDEX.out.fasta_index)
	.join(SAMTOOLS.out.sorted_bam)
	.join(SAMTOOLS.out.bai)
	.join(ch_reference)

    F5C_EVENTALIGN (
	ch_eventalign_input
    )

    //
    // MODULE: Run m6anet
    //
    M6ANET (
 	F5C_EVENTALIGN.out.eventalign_output
    )

    //
    // MODULE: Run m6A annotation python file
    //
    ch_gtf_input = M6ANET.out.inference
	  .join(ch_gtf)
    
    ANNOTATE_M6A (
	ch_gtf_input
    )

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'polyamod_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
