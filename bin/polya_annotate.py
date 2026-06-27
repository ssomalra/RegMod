import pyranges as pr
import pandas as pd
import os
import argparse

# read and clean Nanopolish polyA output
def load_polya(polya_input):
    polya = pd.read_csv(polya_input, sep="\t")
    print("First 5 rows of polya df:")
    print(polya.head())

    polya = polya[polya["qc_tag"] == "PASS"]    # filter to PASS reads only
    polya["contig"] = polya["contig"].str.split("|").str[0]

    return polya


# read GTF file and extract transcript annotations
def load_gtf(gtf_input):
    gtf = pr.read_gtf(gtf_input)
    print("First 5 rows of GTF:")
    print(gtf.head(5))

    gtf_transcripts = (
        gtf[gtf.Feature == "transcript"]
        .df[["transcript_id", "Chromosome", "Start", "End", "Strand", "gene_id", "gene_type", "gene_name", "transcript_name", "transcript_type"]]
        .drop_duplicates("transcript_id")
    )

    return gtf_transcripts


# merge Nanopolish outputs with transcript annotations
def annotate_polya(polya, gtf_transcripts):
    return polya.merge(
        gtf_transcripts,
        left_on="contig",
        right_on="transcript_id",
        how="left"
    )


# rename and reorder columns for the final output
def format_output(polya_annotated):
    polya_final = polya_annotated.rename(
        columns={
            "Chromosome": "chr",
            "Start": "start",
            "End": "end",
            "Strand": "strand"
        }
    )

    polya_final["start"] = polya_final["start"].astype("Int64")
    polya_final["end"] = polya_final["end"].astype("Int64")

    polya_final = polya_final[
        ["chr", "start", "end", "readname", "polya_length", "strand",                                   # polyadenylated transcript info
       "gene_id", "gene_name", "gene_type", "transcript_id", "transcript_name", "transcript_type",      # GTF info
       "position", "leader_start", "adapter_start", "polya_start", "transcript_start", "read_rate"]     # nanopolish info 
    ]
    print("First 5 rows of annotated polyA output:")
    print(polya_final.head())

    return polya_final


# write annotated table
def save_output(df, sample_id):
    output_path = f"{sample_id}_polyA_annotated.tsv"
    df.to_csv(output_path, sep="\t", index=False)
    print(f"Annotated file saved to {output_path}")


# run the complete annotation workflow
def run_annotation(polya_input, gtf_input, sample_id):
    polya = load_polya(polya_input)
    gtf_transcripts = load_gtf(gtf_input)
    polya_annotated = annotate_polya(polya, gtf_transcripts)
    polya_final = format_output(polya_annotated)
    save_output(polya_final, sample_id)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Annotate Nanopolish PolyA results")
    parser.add_argument('--input', required=True, help="Path to Nanopolish polya output TSV file")
    parser.add_argument('--gtf', required=True, help="Path to GTF file")
    parser.add_argument('--id', required=True, help="Sample ID for output filename")
    args = parser.parse_args()

    # call the function with the parsed arguments
    run_annotation(args.input, args.gtf, args.id)

