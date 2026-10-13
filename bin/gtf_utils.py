import re
import sys
import pandas as pd
import pyranges as pr

# the 8 non-attribute GTF columns, as named by pyranges
GTF_FIXED_COLS = ["Chromosome", "Source", "Feature", "Start", "End", "Score", "Strand", "Frame"]
COORD_COLS = ["Chromosome", "Start", "End", "Strand"]

# transcript_id and gene_id are the only attributes the GTF format itself requires,
# so they are the only attribute names referenced anywhere in the annotation scripts.
# Every other attribute is discovered from the file and passed through under its own name.


# read a GTF file and check that it contains what the annotation scripts need
def load_gtf(gtf_input):
    gtf = pr.read_gtf(gtf_input)
    print("First 5 rows of GTF:")
    print(gtf.head(5))

    if "transcript_id" not in gtf.columns:
        sys.exit(f"ERROR: no 'transcript_id' attribute found in {gtf_input}")
    if not (gtf.Feature == "exon").any():
        sys.exit(f"ERROR: no 'exon' features found in {gtf_input}")
    if "gene_id" not in gtf.columns:
        print(f"WARNING: no 'gene_id' attribute found in {gtf_input}; gene-level annotations will be skipped", file=sys.stderr)

    return gtf


# attribute columns that hold at least one value, in file order
def attribute_columns(df):
    return [c for c in df.columns if c not in GTF_FIXED_COLS and df[c].notna().any()]


# attributes that never take more than one value within a group (e.g. within a transcript)
def constant_attributes(df, key):
    attrs = [c for c in attribute_columns(df) if c != key]
    if not attrs:
        return []
    max_values = df.groupby(key)[attrs].nunique().max()

    return [c for c in attrs if max_values[c] <= 1]


# collapse rows sharing a key into one row spanning all of them
def derive_spans(df, key, attrs):
    df = df.astype({"Chromosome": str, "Strand": str})
    agg = {"Chromosome": "first", "Start": "min", "End": "max", "Strand": "first"}
    agg.update({c: "first" for c in attrs})    # first non-null value

    return df.groupby(key, sort=False).agg(agg).reset_index()


# one row per transcript: coordinates plus transcript-level attributes
def transcript_table(gtf_df):
    df = gtf_df[gtf_df["transcript_id"].notna()]
    tx_rows = df[df["Feature"] == "transcript"].drop_duplicates("transcript_id")
    tables = []
    attrs = None

    if len(tx_rows) > 0:
        attrs = [c for c in attribute_columns(tx_rows) if c != "transcript_id"]
        tables.append(tx_rows[COORD_COLS + ["transcript_id"] + attrs].astype({"Chromosome": str, "Strand": str}))

    # transcripts without a 'transcript' row are rebuilt from their exons
    exon_rows = df[(df["Feature"] == "exon") & ~df["transcript_id"].isin(tx_rows["transcript_id"])]
    if len(exon_rows) > 0:
        if attrs is None:
            attrs = constant_attributes(exon_rows, "transcript_id")
        tables.append(derive_spans(exon_rows, "transcript_id", attrs))

    return pd.concat(tables, ignore_index=True)[COORD_COLS + ["transcript_id"] + attrs]


# one row per gene: coordinates plus gene-level attributes (None if the GTF has no gene_id)
def gene_table(gtf_df):
    if "gene_id" not in gtf_df.columns:
        return None

    df = gtf_df[gtf_df["gene_id"].notna()]
    gene_rows = df[df["Feature"] == "gene"].drop_duplicates("gene_id")
    tables = []

    if len(gene_rows) > 0:
        tables.append(gene_rows.astype({"Chromosome": str, "Strand": str, "Feature": str}))

    # genes without a 'gene' row are rebuilt from their other features
    other_rows = df[~df["gene_id"].isin(gene_rows["gene_id"])]
    if len(other_rows) > 0:
        if len(gene_rows) > 0:
            attrs = [c for c in attribute_columns(gene_rows) if c != "gene_id"]
        else:
            attrs = constant_attributes(other_rows, "gene_id")
        derived = derive_spans(other_rows, "gene_id", attrs)
        derived["Feature"] = "gene"
        tables.append(derived)

    return pd.concat(tables, ignore_index=True)


# drop a trailing version number (e.g. ".3") from an ID
def strip_version(tx_id):
    return re.sub(r"\.\d+$", "", tx_id)


# rewrite transcript IDs from reads/sites into the form used by the GTF
def match_transcript_ids(query_ids, gtf_ids):
    """
    IDs are matched exactly first. IDs left over are retried ignoring a trailing
    version number, for when only one of the two sources is versioned.
    IDs with no match are returned unchanged.
    """
    known = set(gtf_ids.dropna().unique())

    # unversioned form -> GTF ID, only where it points to a single transcript
    unversioned = {}
    for gtf_id in known:
        unversioned.setdefault(strip_version(gtf_id), []).append(gtf_id)
    unversioned = {k: v[0] for k, v in unversioned.items() if len(v) == 1}

    mapping = {}
    queries = query_ids.dropna().unique()
    for query in queries:
        stripped = strip_version(query)
        if query in known:
            mapping[query] = query
        elif stripped in known:                             # reads versioned, GTF not
            mapping[query] = stripped
        elif stripped == query and query in unversioned:    # GTF versioned, reads not
            mapping[query] = unversioned[query]

    print(f"\n{len(mapping)} of {len(queries)} transcript IDs matched to the GTF")
    if len(queries) > 0 and len(mapping) == 0:
        print("WARNING: no transcript IDs matched the GTF", file=sys.stderr)
        print(f"  input IDs: {list(queries[:3])}", file=sys.stderr)
        print(f"  GTF IDs:   {sorted(known)[:3]}", file=sys.stderr)

    return query_ids.map(mapping).fillna(query_ids)
