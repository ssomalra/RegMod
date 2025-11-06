#!/bin/bash
#SBATCH --mail-user=ssomalra@iu.edu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=5
#SBATCH --mem=25gb
#SBATCH --time=3-23:59:00
#SBATCH --mail-type=BEGIN,FAIL,END
#SBATCH --job-name=polyamod
#SBATCH -o polyamod.out
#SBATCH -A r00270

module load conda
module load java/17.0.7
module load apptainer

nextflow run . -profile test,conda,singularity --input assets/samplesheet.csv --outdir polyamod_test -resume



