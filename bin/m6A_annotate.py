import pyranges as pr
import pandas as pd
import os
import argparse

def annotate_m6A(m6A_sites, gtf_input, id):
    """
    Computes m6A coordinates on the transcript using m6anet transcript_pos information and annotates them using GTF information.
    Parameters:
    - m6A_sites: path to m6anet inference data.site_proba.csv file
    - gtf_input: path to GTF file
    - id: sample ID for output filename
    NOTE: PyRanges uses 0-based coordinates; GTF is 1-based inclusive, but pyranges converts automatically
    """

    ### STEP 1: COMPUTE M6A COORDINATES
    # prepare the m6A sites file
    sites = pd.read_csv(m6A_sites)
    sites["transcript_id"] = sites["transcript_id"].str.split("|").str[0]  # clean transcript_id values

    # prepare gtf file
    gtf = pr.read_gtf(gtf_input)

    # build exon tables per transcript
    exons = gtf[gtf.Feature == "exon"]
    exons_df = exons.df[["Chromosome", "Start", "End", "Strand", "transcript_id"]]

    # group exons by transcript
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

    # map transcript_pos to genomic coordinates
    def tx_to_genome(tx_id, tx_pos):
        tx_exons = exon_dict.get(tx_id)

        if tx_exons is None:
            return None

        remaining = tx_pos

        for _, row in tx_exons.iterrows():
            if remaining < row.exon_len:   # check if transcript_pos lies within this exon
                # compute genomic coordinate
                if row.Strand == "+":
                    gpos = row.Start + remaining
                else:
                    gpos = row.End - remaining - 1
                return row.Chromosome, gpos, gpos+1, row.Strand
            remaining -= row.exon_len      # else, subtract this exon's length from transcript_pos and continue

        return None

    coords = []                            # map transcript_pos to genomic location

    for r in sites.itertuples(index=False):
        out = tx_to_genome(r.transcript_id, r.transcript_position)
        if out is None:
            coords.append([None, None, None, None])
        else:
            coords.append(list(out))

    coord_cols = ["Chromosome", "Start", "End", "Strand"]
    sites[coord_cols] = pd.DataFrame(coords, index=sites.index)

    # reorder columns
    sites = sites[["Chromosome", "Start", "End", "Strand", "transcript_id", "transcript_position", "n_reads", "probability_modified", "kmer", "mod_ratio"]]

    ### STEP 2: ANNOTATE M6A COORDINATES USING GTF FILE
    # split valid (no NULLs) and invalid (NULLs) rows
    valid_sites = sites.dropna(subset=coord_cols).copy()
    invalid_sites = sites[sites[coord_cols].isna().any(axis=1)].copy()

    # run PyRanges on only valid sites
    valid_sites["Start"] = valid_sites["Start"].astype(int)
    valid_sites["End"] = valid_sites["End"].astype(int)

    m6a_pr = pr.PyRanges(valid_sites)

    # join gtf feature annotations to m6a_pr
    tx_hits = m6a_pr.join(gtf, strandedness="same")
    tx_hits = tx_hits[tx_hits.transcript_id == tx_hits.transcript_id_b]

    # get gene-level annotation
    gtf_genes = gtf.df[(gtf.df.Feature == "gene") & (gtf.df.gene_id.isin(tx_hits.gene_id.unique()))].copy()

    gtf_genes = gtf_genes.rename(columns={
        "Start": "Start_b",
        "End": "End_b",
        "Strand": "Strand_b",
        "transcript_id": "transcript_id_b"
    })

    # attach gene feature rows to each unique m6A site
    site_rows = tx_hits.df[["Chromosome", "Start", "End", "Strand", "transcript_id", "transcript_position", "n_reads", "probability_modified", "kmer", "mod_ratio", "gene_id"]].drop_duplicates()
    gene_rows = site_rows.merge(gtf_genes, on="gene_id", how="left")
    gene_rows = gene_rows.rename(columns={"Chromosome_x": "Chromosome"})
    gene_rows = gene_rows.drop(columns=["Chromosome_y"])

    # create a unique id
    tx_hits.df['site_id'] = tx_hits.df['transcript_id'] + '_' + tx_hits.df['transcript_position'].astype(str)
    gene_rows['site_id'] = gene_rows['transcript_id'] + '_' + gene_rows['transcript_position'].astype(str)

    # add gene row to tx_hits
    final_rows = []

    for site_id, site_group in tx_hits.df.groupby(['transcript_id', 'transcript_position'], sort=False):
        # site_group starts with transcript row
        transcript_row = site_group.iloc[0]
        gene_id = transcript_row['gene_id']

        # get corresponding gene row from gtf_gene
        gene_row = gtf_genes[gtf_genes['gene_id'] == gene_id].copy()

        # ensure all m6a columns exist in gene_row
        for col in ['Chromosome', 'Start', 'End', 'Strand', 'transcript_id', 'transcript_position', 'n_reads', 'probability_modified', 'kmer', 'mod_ratio']:
            gene_row[col] = transcript_row[col]                        # copy the values

        # reorder columns to match tx_hits
        gene_row = gene_row[tx_hits.df.columns]

        # append gene row on top of the m6A site group
        final_rows.append(pd.concat([gene_row, site_group], ignore_index=True))

    final_df = pd.concat(final_rows, ignore_index=True)                # combine all groups

    # all columns expected in final output
    final_cols = ["Chromosome", "Start", "End", "transcript_position", # m6a coords
        "Feature", "Start_b", "End_b", "Strand",                       # GTF info
        "n_reads", "probability_modified", "kmer", "mod_ratio",        # m6a site confidence
        "gene_id", "gene_name", "gene_type",                           # additional GTF info
        "transcript_id", "transcript_name", "transcript_type",
        "exon_number", "exon_id", "protein_id"]

    # keep original columns + add missing ones as NA
    for col in final_cols:
        if col not in invalid_sites.columns:
            invalid_sites[col] = None

    # reorder columns to match output
    invalid_sites = invalid_sites[final_cols]
    final_df = final_df[final_cols]

    # combine valid and invalid rows back together
    filtered_df = pd.concat([final_df, invalid_sites], ignore_index=True)

    # save the output
    output_path = f"{id}_m6A_annotated.tsv"
    filtered_df.to_csv(output_path, sep='\t', index=False)
    print(f"Annotated file saved to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Annotate m6Anet m6A modification results")
    parser.add_argument('--input', required=True, help="Path to data.site_proba.csv file")
    parser.add_argument('--gtf', required=True, help="Path to GTF file")
    parser.add_argument('--id', required=True, help="Sample ID for output filename")
    args = parser.parse_args()

    # call the function with the parsed arguments
    annotate_m6A(args.input, args.gtf, args.id)
