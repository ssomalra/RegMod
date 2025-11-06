/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { GUPPY_BASECALL         } from '../modules/local/guppy/main.nf' 
include { PREP_FASTQ             } from '../modules/local/prep_fastq/main.nf'  
include { F5C_INDEX              } from '../modules/local/f5c/index/main.nf'
include { MINIMAP2_ALIGN         } from '../modules/local/minimap/main.nf'
include { SAMTOOLS               } from '../modules/local/samtools/main.nf'
include { BAM_TO_BED             } from '../modules/local/bedtools/main.nf'
include { NANOPOLISH_POLYA 	 } from '../modules/local/nanopolish/main.nf'
include { F5C_EVENTALIGN	 } from '../modules/local/f5c/eventalign/main.nf'
include { M6ANET		 } from '../modules/local/m6anet/main.nf'
include { ANNOTATE_POLYA	 } from '../modules/local/annotate/annotate_polyA/main.nf'
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

    //
    // MODULE: Run Guppy
    // 
    GUPPY_BASECALL (
	ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,fast5_dir,flowcell_id,sequencing_kit)}
    )

    //
    // MODULE: Convert fastq to fasta
    //        
    PREP_FASTQ (
        GUPPY_BASECALL.out.guppy
    )

    //
    // MODULE: Run f5c index
    //
    F5C_INDEX (
	GUPPY_BASECALL.out.guppy,
	PREP_FASTQ.out.fasta
    )

    //
    // MODULE: Run minimap2 
    //
    MINIMAP2_ALIGN (
	ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,reference_genome)},
	PREP_FASTQ.out.fasta
    )

    //
    // MODULE: Samtools flagstat, view, sort, and index
    // 
    SAMTOOLS (
	MINIMAP2_ALIGN.out.sam
    )

    //
    // MODULE: Run Bedtools bamtobed
    //
    BAM_TO_BED (
	SAMTOOLS.out.sorted_bam
    )

    //
    // MODULE: Run nanopolish poly(A)
    //
    NANOPOLISH_POLYA (
	ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,reference_genome)},
	PREP_FASTQ.out.fasta,
	F5C_INDEX.out.fasta_index,
	GUPPY_BASECALL.out.guppy,
	SAMTOOLS.out.sorted_bam,
	SAMTOOLS.out.bai,
	BAM_TO_BED.out.reads_bed
    )

    //
    // MODULE: Run polyA annotation python file
    //
    ANNOTATE_POLYA (
        NANOPOLISH_POLYA.out.polya_reads,
        ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,gtf)}
    )

    //
    // MODULE: Run f5c eventalign
    // 
    F5C_EVENTALIGN (
	ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,reference_genome)},
	GUPPY_BASECALL.out.guppy,
	PREP_FASTQ.out.fasta,
	F5C_INDEX.out.fasta_index,
	SAMTOOLS.out.sorted_bam,
	SAMTOOLS.out.bai
    )

    //
    // MODULE: Run m6anet
    //
    M6ANET (
 	F5C_EVENTALIGN.out.eventalign_output,
	BAM_TO_BED.out.reads_bed
    )

    //
    // MODULE: Get m6A coordinates
    //
    M6A_COORDINATES (
	M6ANET.out.inference,
	BAM_TO_BED.out.reads_bed
    )

    //
    // MODULE: Run m6A annotation python file
    //
    ANNOTATE_M6A (
        M6A_COORDINATES.out.m6A_coordinates,
        ch_samplesheet.map{sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,gtf)}
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
