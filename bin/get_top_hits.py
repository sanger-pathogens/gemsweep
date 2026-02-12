#!/usr/bin/env python3

import argparse
from pathlib import Path

import pandas as pd

def parse_args():
    parser = argparse.ArgumentParser(
        description='Get top hits from hits.csv',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('--skani_report', type=Path, help='Path to skani report file', required=True)
    parser.add_argument('--filter', action='store_true', help='Whether to filter by thresholds', required=False)
    parser.add_argument('--n_reps', type=int, help='Number of representatives to return', required=False)
    parser.add_argument('--ani_threshold', type=float, help='ANI threshold', required=False, default=95.0)
    parser.add_argument('--aligned_frac_ref', type=float, help='Aligned fraction reference threshold', required=False, default=0.5)
    parser.add_argument('--aligned_frac_query', type=float, help='Aligned fraction query threshold', required=False, default=0.8)
    parser.add_argument('--accession_pattern', type=str, help='Regular expression to extract accessions', required=False, default=None)
    parser.add_argument('--output_dir', type=Path, help='Path to output file for top hits', required=False, default=Path.cwd())
    return parser.parse_args()

def read_skani_report(skani_report: Path):
    df = pd.read_csv(skani_report, sep="\t")
    return df

def get_top_hits(df: pd.DataFrame):
    sorted_df = df.groupby('Query_file').apply(lambda x: x.sort_values(by='ANI', ascending=False))
    top_hits = sorted_df.groupby('Query_file').head(1)
    return top_hits

def filter_ani(df: pd.DataFrame, ani_threshold=95.0, aligned_frac_ref=0.5, aligned_frac_query=0.8):
    return df.loc[
        df['ANI'] >= ani_threshold & \
        df['Align_fraction_ref'] >= aligned_frac_ref & \
        df['Align_fraction_query'] >= aligned_frac_query
    ]

def get_representatives(df: pd.DataFrame, n_reps=None):
    unique_assemblies = pd.Series(df['Ref_file'].unique())
    if n_reps is None:
        return unique_assemblies
    else:
        return unique_assemblies.sample(n_reps, random_state=1234)

def extract_ref_accessions(column: pd.Series, accession_pattern='.*/(.*)_genomic.fna.gz'):
    print(column.head())
    return column.str.extract(accession_pattern)

def write_output(df: pd.DataFrame, output_path: Path):
    df.to_csv(output_path, index=False)

def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    df = read_skani_report(args.skani_report)
    top_hits = get_top_hits(df)
    if args.filter:
        top_hits = filter_ani(top_hits, ani_threshold=args.ani_threshold, aligned_frac_ref=args.aligned_frac_ref, aligned_frac_query=args.aligned_frac_query)
    representatives = get_representatives(top_hits, n_reps=args.n_reps)
    if args.accession_pattern:
        representatives = extract_ref_accessions(representatives, accession_pattern=args.accession_pattern)
    output_file = args.output_dir / 'top_hits.txt'
    write_output(representatives, output_file)

if __name__ == "__main__":
    main()
