/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { GUPPY_BASECALL         } from '../modules/local/guppy/main.nf'
include { F5C_INDEX              } from '../modules/local/f5c/index/main.nf'
include { MINIMAP2_ALIGN         } from '../modules/local/minimap/main.nf'
include { SAMTOOLS               } from '../modules/local/samtools/main.nf'
include { NANOPOLISH_POLYA 	     } from '../modules/local/nanopolish/main.nf'
include { COMBINE_NANOPOLISH_POLYA } from '../modules/local/nanopolish/combine/main.nf'
include { ANNOTATE_POLYA         } from '../modules/local/annotate/annotate_polyA/main.nf'
include { F5C_EVENTALIGN	     } from '../modules/local/f5c/eventalign/main.nf'
include { M6ANET		         } from '../modules/local/m6anet/main.nf'
include { ANNOTATE_M6A		     } from '../modules/local/annotate/annotate_m6A/main.nf'
include { XPORE_DATAPREP         } from '../modules/local/xpore/dataprep/main.nf'
include { XPORE_DIFFMOD          } from '../modules/local/xpore/diffmod/main.nf'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow REGMOD {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    
    main:
    ch_versions = Channel.empty()

    // Define shared channels
    ch_reference = ch_samplesheet.map{sample,condition,replicate,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,reference_genome)}
    ch_gtf = ch_samplesheet.map{sample,condition,replicate,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,gtf)}
    ch_condition_replicate = ch_samplesheet.map{sample,condition,replicate,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,condition,replicate)}

    // MODULE: Run Guppy
    GUPPY_BASECALL (
	    ch_samplesheet.map{sample,condition,replicate,fast5_dir,flowcell_id,sequencing_kit,reference_genome,gtf -> tuple(sample,fast5_dir,flowcell_id,sequencing_kit)}
    )

    // MODULE: Convert fasta > fastq and run f5c index
    F5C_INDEX (
	    GUPPY_BASECALL.out.guppy
    )

    // Split each sample's merged fasta round-robin into N independent chunks.
    // This chunking is only used for the nanopolish poly(A) branch and does
    // not affect the full-fasta eventalign/m6A branch.
    ch_chunk_fasta = F5C_INDEX.out.fasta
        .splitFasta(by: 1, record: [id: true, seqString: true])
        .groupTuple()
        .flatMap { meta, records ->
            records.withIndex().collect { record, i -> tuple(meta.id, i % params.nanopolish_chunks, record) }
        }
        .collectFile() { id, chunk, record ->
            [ "${id}_chunk${chunk}.fasta", ">${record.id}\n${record.seqString}\n" ]
        }
        .map { file ->
            def (id, chunk) = (file.baseName =~ /^(.+)_chunk(\d+)$/)[0][1..2]
            tuple([id: "${id}_chunk${chunk}", sample: id, chunk: chunk as Integer], file)
        }

    // MODULE: Run minimap2 on the full fasta and each round-robin chunk
    ch_minimap_input = F5C_INDEX.out.fasta
	    .join(ch_reference)

    ch_minimap_chunk_input = ch_chunk_fasta
        .map { meta, fasta -> tuple(meta.sample, meta, fasta) }
        .combine(ch_reference.map { meta, reference_genome -> tuple(meta.id, reference_genome) }, by: 0)
        .map { sample, meta, fasta, reference_genome -> tuple(meta, fasta, reference_genome) }

    MINIMAP2_ALIGN (
	    ch_minimap_input.mix(ch_minimap_chunk_input)
    )

    // MODULE: Samtools flagstat, view, sort, and index
    SAMTOOLS (
	    MINIMAP2_ALIGN.out.sam
    )

    // Split the merged alignment output back into the full-sample and
    // per-chunk branches so each can be routed to its own downstream module.
    ch_samtools_out = SAMTOOLS.out.sorted_bam
        .join(SAMTOOLS.out.bai)
        .branch { meta, sorted_bam, bai ->
            chunk: meta.chunk != null
            full:  meta.chunk == null
        }

    // MODULE: Run nanopolish poly(A) on each chunk, reusing the whole-sample f5c index
    ch_nanopolish_input = ch_samtools_out.chunk
        .join(ch_chunk_fasta)
        .map { meta, sorted_bam, bai, fasta -> tuple(meta.sample, meta, fasta, sorted_bam, bai) }
        .combine(GUPPY_BASECALL.out.guppy.map    { meta, guppy -> tuple(meta.id, guppy) }, by: 0)
        .combine(F5C_INDEX.out.fasta_index.map   { meta, fasta_index -> tuple(meta.id, fasta_index) }, by: 0)
        .combine(ch_reference.map                { meta, reference_genome -> tuple(meta.id, reference_genome) }, by: 0)
        .map { sample, meta, fasta, sorted_bam, bai, guppy, fasta_index, reference_genome ->
            tuple(meta, guppy, fasta, fasta_index, sorted_bam, bai, reference_genome)
        }

    NANOPOLISH_POLYA (
	    ch_nanopolish_input
    )

    // MODULE: Combine per-chunk nanopolish poly(A) TSVs back into one TSV per sample
    ch_nanopolish_combine_input = NANOPOLISH_POLYA.out.nanopolish_polya
        .map { meta, tsv -> tuple(meta.sample, tsv) }
        .groupTuple()
        .map { sample, tsvs -> tuple([id: sample], tsvs) }

    COMBINE_NANOPOLISH_POLYA (
        ch_nanopolish_combine_input
    )

    // MODULE: Run polyA annotation python file
    ch_annotate_polya_input = COMBINE_NANOPOLISH_POLYA.out.nanopolish_polya
        .join(ch_gtf)

    ANNOTATE_POLYA (
        ch_annotate_polya_input
    )

    // MODULE: Run f5c eventalign
    ch_eventalign_input = GUPPY_BASECALL.out.guppy
	    .join(F5C_INDEX.out.fasta)
	    .join(F5C_INDEX.out.fasta_index)
	    .join(ch_samtools_out.full)
	    .join(ch_reference)

    F5C_EVENTALIGN (
	    ch_eventalign_input
    )

    // MODULE: Run m6anet
    M6ANET (
 	    F5C_EVENTALIGN.out.eventalign_output
    )

    // MODULE: Run m6A annotation python file
    ch_gtf_input = M6ANET.out.m6anet_inference
	    .join(ch_gtf)
    
    ANNOTATE_M6A (
	    ch_gtf_input
    )

    // MODULE: Run xPore dataprep and diffmod
    if (params.run_xpore) {
        XPORE_DATAPREP (
            F5C_EVENTALIGN.out.eventalign_output
        )

        ch_xpore_samples = XPORE_DATAPREP.out.xpore_dataprep
            .join(ch_condition_replicate)
            .map { meta, dataprep_dir, condition, replicate ->
                [condition: condition, replicate: replicate, dataprep_dir: dataprep_dir]
            }
            .collect()

        XPORE_DIFFMOD (
            Channel.value(file(params.xpore_model)),
            ch_xpore_samples
        )
    }

    // Collate and save software versions
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'regmod_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
        versions = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
