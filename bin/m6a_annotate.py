import pyranges as pr
import pandas as pd
import os
import argparse

COORD_COLS = ["Chromosome", "Start", "End", "Strand"]

# Load m6Anet sites and GTF annotations
def load_input_data(m6A_sites, gtf_input):
    sites = pd.read_csv(m6A_sites)
    sites["transcript_id"] = sites["transcript_id"].str.split("|").str[0]
    print("First 5 rows of m6a df:")
    print(sites.head())

    gtf = pr.read_gtf(gtf_input)
    print("\nFirst 5 rows of GTF:")
    print(gtf.head(5))

    return sites, gtf


##### COMPUTE M6A GENOMIC COORDINATES #####
# build exon tables grouped by transcript
def build_exon_dictionary(gtf):
    exons = gtf[gtf.Feature == "exon"]
    exons_df = exons.df[["Chromosome", "Start", "End", "Strand", "transcript_id"]]

    exon_dict = {}

    for tx_id, df in exons_df.groupby("transcript_id"):
        # sort exons according to transcript direction
        strand = df.iloc[0].Strand
        if strand == "+":
            df = df.sort_values("Start")
        else:
            df = df.sort_values("Start", ascending=False)
        
        # compute exon lengths
        df = df.copy()
        df["exon_len"] = df.End - df.Start
        exon_dict[tx_id] = df
    
    return exon_dict


# convert transcript position to genomic coordinates
def tx_to_genome(tx_id, tx_pos, exon_dict):
    tx_exons = exon_dict.get(tx_id)

    if tx_exons is None:
        return None
    
    remaining = tx_pos

    for _, row in tx_exons.iterrows():
        if remaining < row.exon_len:    # check if transcript_pos lies within this exon
            # compute genomic coordinate
            if row.Strand == "+":
                gpos = row.Start + remaining
            else:
                gpos = row.End - remaining - 1
            
            return (
                row.Chromosome,
                gpos,
                gpos + 1,
                row.Strand
            )
        
        remaining -= row.exon_len       # else, subtract this exon's length from transcript_pos and continue
    
    return None


# map transcript positions to genomic coordinates
def map_transcript_positions(sites, exon_dict):
    coords = []

    for row in sites.itertuples(index=False):
        coord = tx_to_genome(
            row.transcript_id,
            row.transcript_position,
            exon_dict
        )

        if coord is None:
            coords.append([None, None, None, None])
        else:
            coords.append(list(coord))
    
    sites[COORD_COLS] = pd.DataFrame(coords, index=sites.index,)

    return sites


##### ANNOTATE M6A COORDINATES USING GTF FILE #####
def annotate_sites(sites, gtf):
    """
    Annotate m6A genomic coordinates using GTF features

    Returns:
        final_df: annotated valid m6A sites
        invalid_sites: sites that could not be mapped to the genome
    """

    # split mapped and unmapped sites
    valid_sites = sites.dropna(subset=COORD_COLS).copy()
    invalid_sites = sites[sites[COORD_COLS].isna().any(axis=1)].copy()

    # run PyRanges on only valid sites
    valid_sites["Start"] = valid_sites["Start"].astype(int)
    valid_sites["End"] = valid_sites["End"].astype(int)

    m6a_pr = pr.PyRanges(valid_sites)

    # join gtf feature annotations to m6a_pr
    tx_hits = m6a_pr.join(gtf, strandedness="same")
    tx_hits = tx_hits[tx_hits.transcript_id == tx_hits.transcript_id_b]

    # get gene-level annotations
    gtf_genes = gtf.df[
        (gtf.df.Feature == "gene") & 
        (gtf.df.gene_id.isin(tx_hits.gene_id.unique()))
        ].copy()

    gtf_genes = gtf_genes.rename(columns={
        "Start": "Start_b",
        "End": "End_b",
        "Strand": "Strand_b",
        "transcript_id": "transcript_id_b"
    })

    site_rows = tx_hits.df[
        ["Chromosome", "Start", "End", "Strand", "transcript_id", "transcript_position",
        "n_reads", "probability_modified", "kmer", "mod_ratio", "gene_id",]
    ].drop_duplicates()

    # prepend a gene row to each site annotation
    final_rows = []

    for (_, _), site_group in tx_hits.df.groupby(["transcript_id", "transcript_position"], sort=False):
        transcript_row = site_group.iloc[0]
        gene_id = transcript_row["gene_id"]
        gene_row = gtf_genes[gtf_genes["gene_id"] == gene_id].copy()

        # copy m6a site information into gene row
        for col in ["Chromosome", "Start", "End", "Strand", "transcript_id", "transcript_position", "n_reads", "probability_modified", "kmer", "mod_ratio"]:
            gene_row[col] = transcript_row[col]

        gene_row = gene_row[tx_hits.df.columns]

        final_rows.append(pd.concat([gene_row, site_group], ignore_index=True))
    
    final_df = pd.concat(final_rows, ignore_index=True)
    
    return final_df, invalid_sites


# reorder columns, add missing columns to invalid sites, and combine valid and invalid annotations
def format_output(final_df, invalid_sites):
    rename_dict = {
        "Chromosome": "chr",
        "Start": "mod_start",
        "End": "mod_end",
        "Strand": "strand",
        "Feature": "feature",
        "transcript_position": "transcript_pos",
        "Start_b": "feature_start",
        "End_b": "feature_end"
    }
    
    final_df = final_df.rename(columns=rename_dict)
    invalid_sites = invalid_sites.rename(columns=rename_dict)
    
    final_cols = [
        "chr", "mod_start", "mod_end", "strand",                          # m6a coords
        "feature", "transcript_pos", "feature_start", "feature_end",      # GTF info
        "n_reads", "probability_modified", "kmer", "mod_ratio",           # m6a site confidence
        "gene_id", "gene_name", "gene_type",                              # additional GTF info
        "transcript_id", "transcript_name", "transcript_type",
        "exon_number", "exon_id", "protein_id"
    ]
    
    # add any missing columns to invalid rows
    for col in final_cols:
        if col not in invalid_sites.columns:
            invalid_sites[col] = None
        if col not in final_df.columns:
            final_df[col] = None
    
    final_df = final_df[final_cols]
    invalid_sites = invalid_sites[final_cols]

    # combine annotated and unannotated sites
    output_df = pd.concat([final_df, invalid_sites], ignore_index=True)
    print("First 5 rows of annotated m6A sites output:")
    print(output_df.head())
    
    return output_df


# write annotated table
def save_output(df, sample_id):
    output_path = f"{sample_id}_m6A_annotated.tsv"
    df.to_csv(output_path, sep="\t", index=False)
    print(f"Annotated file saved to {output_path}")


def annotate_m6A(m6A_sites, gtf_input, sample_id):
    sites, gtf = load_input_data(m6A_sites, gtf_input)
    exon_dict = build_exon_dictionary(gtf)
    sites = map_transcript_positions(sites, exon_dict)
    final_df, invalid_sites = annotate_sites(sites, gtf)
    output_df = format_output(final_df, invalid_sites)
    save_output(output_df, sample_id)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Annotate m6Anet m6A modification results")
    parser.add_argument('--input', required=True, help="Path to data.site_proba.csv file")
    parser.add_argument('--gtf', required=True, help="Path to GTF file")
    parser.add_argument('--id', required=True, help="Sample ID for output filename")
    args = parser.parse_args()

    # call the function with the parsed arguments
    annotate_m6A(args.input, args.gtf, args.id)
