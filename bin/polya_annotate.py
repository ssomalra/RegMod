import pyranges as pr
import pandas as pd
import os
import argparse

def annotate_polya(polya_input, gtf_input, id):
    """
    Annotates nanopolish polyA results using GTF information

    Parameters:
    - polya_input: path to Nanopolish polya output TSV file
    - gtf_input: path to GTF file
    - id: sample ID for output filename
    """

    # read polya input file
    polya = pd.read_csv(polya_input, sep="\t")
    print("First 5 rows of polya df:")
    print(polya.head())
    
    polya = polya[polya["qc_tag"] == "PASS"] # filter to PASS reads only
    polya["contig"] = polya["contig"].str.split("|").str[0]  # clean contig values

    # read GTF file
    gtf = pr.read_gtf(gtf_input)
    print("First 5 rows of GTF:")
    print(gtf.head())

    # get columns of interest from GTF file
    gtf_transcripts = gtf[gtf.Feature == "transcript"].df[["transcript_id", "Chromosome", "Start", "End", "Strand", "gene_id", "gene_type", "gene_name", "transcript_name", "transcript_type"]].drop_duplicates("transcript_id")

    # annotate polya df using GTF features
    polya_annotated = polya.merge(gtf_transcripts, left_on="contig", right_on="transcript_id", how="left")

    # format final output
    polya_annotated = polya_annotated[
    ["Chromosome", "Start", "End", "readname", "polya_length", "Strand",                            # polyadenylated transcript info
    "gene_id", "gene_name", "gene_type", "transcript_id", "transcript_name", "transcript_type",     # GTF info
    "position", "leader_start", "adapter_start", "polya_start", "transcript_start", "read_rate"]]   # nanopolish info     

    print("First 5 rows of annotated polyA output:")
    print(polya_annotated.head())

    # save the output
    output_dir = os.path.dirname(polya_input)
    output_path = os.path.join(output_dir, f"{id}_polyA_annotated.tsv")
    polya_annotated.to_csv(output_path, sep='\t', index=False)
    print(f"Annotated file saved to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Annotate Nanopolish PolyA results")
    parser.add_argument('--input', required=True, help="Path to Nanopolish polya output TSV file")
    parser.add_argument('--gtf', required=True, help="Path to GTF file")
    parser.add_argument('--id', required=True, help="Sample ID for output filename")
    args = parser.parse_args()

    # call the function with the parsed arguments
    annotate_polya(args.input, args.gtf, args.id)
    
