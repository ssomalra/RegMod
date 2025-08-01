# nf-core/polyamod

[![GitHub Actions CI Status](https://github.com/nf-core/polyamod/actions/workflows/ci.yml/badge.svg)](https://github.com/nf-core/polyamod/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/polyamod/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/polyamod/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.2-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/polyamod)

## Introduction

**nf-core/polya+mod** is a bioinformatics pipeline that enables joint prediction of poly(A) tail lengths and m6A modifications from ONT direct RNA sequencing data.

<img width="3900" height="850" alt="PolyA_Figure11_PolymodPipeline" src="https://github.com/user-attachments/assets/a7609744-ed8a-483e-ba08-370f089bd460" />

This pipeline was implemented in Nextflow (v24.10.5), a domain-specific workflow management system optimized for scalable and reproducible bioinformatics workflows. It uses Docker/Singularity containers making installation trivial and results highly reproducible.

## Pipeline Summary
polya+mod automates the simultaneous prediction of poly(A) tail lengths and m6A RNA modifications at the transcript- and gene-level.

### Workflow steps:
**1. Basecalling**
   Performed using Guppy to convert raw signal data to FASTQ
   
**2. Preprocessing**
   - FASTQ files are converted to FASTA
   - f5c is used for indexing
     
**3. Alignment**
   - Reads are aligned to user-provided reference genome using minimap2
   - Resulting BAM files are sorted and indexed using SAMtools
     
**4. Downstream Analysis (Two Parallel Paths):**
   - Nanopolish-polyA: Predictions poly(A) tail lengths
   - f5c eventalign + m6Anet: Detected m6A modifications
     
**5. Annotation:**
   - A provided GTF file is used to annotate results
   - Final outputs include:
     - BED file of m6A modification sites
     - BED file of polyadenylated transcripts

Outputs are compatible with genome browsers and can be used in exploratory analyses, such as correlating m6A presence with poly(A) tail length. 

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fast5_dir,flowcell_id,sequencing_kit,reference_genome
CELL_LINE_1,/path/to/fast5/directory/fast5_files,FLO-MIN106,SQK-RNA002,/path/to/reference/genome/Homo_sapiens.GRCh38.cdna.all.fa,/path/to/gtf/file/Homo_sapiens.GRCh38.113_transcripts.gtf
CELL_LINE_2,/path/to/fast5/directory/fast5_files,FLO-MIN106,SQK-RNA002,/path/to/reference/genome/Homo_sapiens.GRCh38.cdna.all.fa,/path/to/gtf/file/Homo_sapiens.GRCh38.113_transcripts.gtf
```

Each row represents a study, containing a directory of fast5 files, flowcell ID, and sequencing kit for basecalling, as well as a reference genome and gene annotation file.

Now, you can run the pipeline using:

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
- David Scheper ()

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
