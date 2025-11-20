# nf-core/polyaxmod

[![GitHub Actions CI Status](https://github.com/nf-core/polyamod/actions/workflows/ci.yml/badge.svg)](https://github.com/nf-core/polyamod/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/polyamod/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/polyamod/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.2-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/polyamod)

## Introduction

**nf-core/polyaxmod** is a bioinformatics pipeline that enables joint prediction of poly(A) tail lengths and m6A modifications from ONT direct RNA sequencing data.

<img width="5406" height="1152" alt="polyAmod_UpdatedPipeline" src="https://github.com/user-attachments/assets/798485fb-3f62-4010-8ef1-f0df65296056" />

This pipeline was implemented in Nextflow (v25.10.0), a domain-specific workflow management system optimized for scalable and reproducible bioinformatics workflows. It uses Docker/Singularity containers making installation trivial and results highly reproducible.

## Pipeline Summary
polyaxmod automates the simultaneous prediction and annotation of poly(A) tail lengths and m6A RNA modifications.

### Workflow steps:
**1. Basecalling**
   - Performed using Guppy to convert raw FAST5 signal data into FASTQ
   
**2. Index FASTA**
   - FASTQ files are merged into a single file and then converted to FASTA format
   - f5c index is used to index FASTA inputs for downstream signal-level analyses
     
**3. Alignment**
   - Reads are aligned to user-provided reference genome using minimap2

**4. Binary Index SAM**
   - Resulting SAM files are converted to BAM format, sorted, and indexed using SAMTools
   - Alignment summary is also outputted

**5. BAM to BED Conversion**
   - Sorted BAM files are converted to BED format using BEDtools bamtobed
   - BED files serve as the backbone for poly(A) and m6A annotations
  
**6. Downstream Analysis (Two Parallel Paths):**
   - m6A Path
       - f5c eventalign aligns raw signals to the reference
       - m6Anet predicts m6A modifications at single-nucleotide resolution
       - BEDtools intersect + custom scripts extract m6A site coordinates
       - A Python script annotates each m6A sites
       - Output: BED file containing m6A modification site locations and corresponding annotations
   - PolyA Path
       - Nanopolish polyA is used to estimate poly(A) tail lengths from signal-level data
       - A Python script annotates poly(A) tail lengths to each read
       - Output: BED file containing polyadenylated reads, predicted tail lengths, and corresponding annotations
     
## Final Outputs Summary
   - m6A site annotation BED file
   - poly(A) tail annotation BED file
   - Intermediate files from preprocessing Nanopore data

[add something about awk to filter annotation file here]

Outputs are compatible with genome browsers and can be used in exploratory analyses, such as correlating m6A presence with poly(A) tail length. 

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

### 1. Prepare a samplesheet with your input data

`samplesheet.csv`:

```csv
sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome
CELL_LINE_1,/path/to/fast5/directory/fast5_files/,FLO-MIN106,SQK-RNA002,/path/to/reference/genome/Homo_sapiens.GRCh38.dna.primary_assembly.fa,/path/to/gtf/file/Homo_sapiens.GRCh38.113.gtf
CELL_LINE_2,/path/to/fast5/directory/fast5_files/,FLO-MIN106,SQK-RNA002,/path/to/reference/genome/Homo_sapiens.GRCh38.dna.primary_assembly.fa,/path/to/gtf/file/Homo_sapiens.GRCh38.113.gtf
```
Each row represents a study, containing a directory of fast5 files, flowcell ID, and sequencing kit for basecalling, as well as a reference genome and gene annotation file.

**Note on Guppy**

A Guppy version *below 6.3.2* must be pre-installed for basecalling, as older versions can output basecalled FAST5 using the `--fast5_out` parameter.
Update the path to your Guppy installation in `nextflow.config`

### 2. Run the Pipeline

```bash
nextflow run nf-core/polyamod \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Credits

nf-core/polyamod was originally written by Sahiti Somalraju.

We thank the following people for their extensive assistance in the development of this pipeline:
- David Schaeper ()

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/polyamod for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
