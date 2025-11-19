import pyranges as pr
import pandas as pd
import os
import argparse

def annotate_polya(polya_bed, gtf_input, id):
    """
    Annotates nanopolish polyA results using GTF information

    Parameters:
    - polya_bed: path to BED file containing read information and corresponding polyA tail lengths
    - gtf_input: path to GTF file
    - id: sample ID for output filename
    """

    # read polya input file
    polya_df = pd.read_csv(polya_bed, sep="\t", header=None, names=["Chromosome", "Start", "End", "Read_ID", "Score", "Strand", "PolyA_Length"])
    print("First 5 rows of polya_df:")
    print(polya_df.head())
    
    polya_pr = pr.PyRanges(polya_df)

    # read GTF file
    gtf = pr.read_gtf(gtf_input)
    print("First 5 rows of GTF:")
    print(gtf.df.head())

    # perform strand-specific intersection
    intersected = polya_pr.join(gtf, strandedness="same")
    print("First 5 rows of intersected:")
    print(intersected.df.head())
    
    # format final output
    final_df = intersected.df[
    ["Chromosome", "Start", "End", "Read_ID", "Score", "Strand", "PolyA_Length", # polyadenylated read info
     "Feature", "Start_b", "End_b", "Strand",  # GTF info
     "gene_id", "gene_name", "gene_biotype",
     "transcript_id", "transcript_name", "transcript_biotype",
     "exon_number", "exon_id", "protein_id", "ccds_id"]
    ]

    # save the output
    output_dir = os.path.dirname(polya_bed)
    output_path = os.path.join(output_dir, f"{id}_polyA_annotated.tsv")
    final_df.to_csv(output_path, sep='\t', index=False)
    print(f"Annotated file saved to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Annotate Nanopolish PolyA results")
    parser.add_argument('--input', required=True, help="Path to BED file containing read information and corresponding polyA tail lengths")
    parser.add_argument('--gtf', required=True, help="Path to GTF file")
    parser.add_argument('--id', required=True, help="Sample ID for output filename")
    args = parser.parse_args()

    # call the function with the parsed arguments
    annotate_polya(args.input, args.gtf, args.id)
    
