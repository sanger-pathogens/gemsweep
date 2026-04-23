#!/usr/bin/env python3

import argparse
from collections import defaultdict
from pathlib import Path

def parse_arguments():
    parser = argparse.ArgumentParser(description="Split a clusters CSV file into multiple cluster CSVs.")
    parser.add_argument("--outdir", type=Path, help="Directory to save output CSV files", default=Path.cwd())
    parser.add_argument("--clusters", type=Path, help="List of samples and their clusters to subset (*.csv)")
    parser.add_argument("--header", help="Specifies whether the clusters file has a header row", action='store_true')
    return parser.parse_args()

def read_clusters(clusters_file: Path, header: bool = False) -> dict:
    # Implement the logic to read the clusters from the CSV file
    # Return a dictionary mapping sample names to cluster IDs
    cluster_to_sample = defaultdict(set)
    with open(clusters_file, 'r') as f:
        if header:
            next(f)  # Skip header line
        for line in f:
            sample, cluster = line.strip().split(',')
            cluster_to_sample[cluster].add(sample)
    return cluster_to_sample

def write_clusters(cluster_to_sample: dict, outdir: Path) -> None:
    for cluster, samples in cluster_to_sample.items():
        with open(outdir / f"{cluster}.csv", "w") as f:
            for sample in samples:
                f.write(f"{sample},{cluster}\n")  #TODO writing cluster inside file is redundant, but keeping for now

if __name__ == "__main__":
    args = parse_arguments()

    args.outdir.mkdir(parents=True, exist_ok=True)

    cluster_to_sample = read_clusters(args.clusters, args.header)
    write_clusters(cluster_to_sample, args.outdir)
