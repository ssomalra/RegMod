import pyranges as pr
import pandas as pd
import os
import argparse

def annotate_m6A(m6A_coords, gtf_input, id):
    """
    Annotates m6anet m6A modification prediction results using GTF information.
    Parameters:
    - m6A_coords: path the TSV file containing m6A_coodinates with strand information
    - gtf_input: path to GTF file
    - id: sample ID for output filename
    """

    # read the m6A inference input file
    m6a_df = pd.read_csv(m6A_coords, sep="\t", header=None, names=["Chromosome", "Start", "End", "Strand"])
    m6a_pr = pr.PyRanges(m6a_df)

    # read GTF input file
    gtf = pr.read_gtf(gtf_input)

    # perform strand-specific intersection
    intersected = m6a_pr.join(gtf, strandedness="same")

    # format final output
    final_df = intersected.df[
    ["Chromosome", "Start", "End",             # m6A coords
     "Feature", "Start_b", "End_b", "Strand",  # GTF info
     "gene_id", "gene_name", "gene_biotype",
     "transcript_id", "transcript_name", "transcript_biotype",
     "exon_number", "exon_id", "protein_id", "ccds_id"]
    ]

    # save the output
    output_dir = os.path.dirname(m6A_coords)
    output_path = os.path.join(output_dir, f"{id}_m6A_annotated.tsv")
    final_df.to_csv(output_path, sep='\t', index=False)
    print(f"Annotated file saved to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Annotate m6Anet m6A modification results")
    parser.add_argument('--input', required=True, help="Path to preprocessed data.site_proba.csv file containing m6A site coordinates and strand information")
    parser.add_argument('--gtf', required=True, help="Path to GTF file")
    parser.add_argument('--id', required=True, help="Sample ID for output filename")
    args = parser.parse_args()

    # call the function with the parsed arguments
    annotate_m6A(args.input, args.gtf, args.id)
