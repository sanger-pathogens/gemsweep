#!/usr/bin/env python3

import argparse
import logging
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd

def parse_arguments():
    parser = argparse.ArgumentParser(description="Subset the distance matrix file into cluster-specific submatrices.")
    parser.add_argument("--matrix", type=Path, help="Path to the matrix file (.dists.npy)")
    parser.add_argument("--outdir", type=Path, help="Directory to save the output submatrices", default=Path.cwd())
    parser.add_argument("--clusters", type=Path, help="List of samples and their clusters to subset (*.csv)")
    parser.add_argument("--header", help="Specifies whether the clusters file has a header row", action='store_true')
    parser.add_argument("--references", type=Path, help="List of references that relate (*.txt)")
    return parser.parse_args()

def read_matrix(matrix_file: Path) -> np.ndarray:
    # Implement the logic to read the matrix from the file
    return np.load(matrix_file)

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


def read_references(references_file: Path) -> set:
    """Return a set of reference labels"""
    references = set()
    with open(references_file, 'r') as f:
        for line in f:
            ref_label = Path(line.strip()).stem.replace('.','_')
            references.add(ref_label)
    return references

def iterDistRows(refSeqs, querySeqs, self=True):
    """Gets the ref and query ID for each row of the distance matrix

    Returns an iterable with ref and query ID pairs by row.

    Args:
        refSeqs (list)
            List of reference sequence names.
        querySeqs (list)
            List of query sequence names.
        self (bool)
            Whether a self-comparison, used when constructing a database.

            Requires refSeqs == querySeqs

            Default is True
    Returns:
        ref, query (str, str)
            Iterable of tuples with ref and query names for each distMat row.
    """
    if self:
        if refSeqs != querySeqs:
            raise RuntimeError('refSeqs must equal querySeqs for db building (self = true)')
        for i, ref in enumerate(refSeqs):
            for j in range(i + 1, len(refSeqs)):
                yield(refSeqs[j], ref)
    else:
        for query in querySeqs:
            for ref in refSeqs:
                yield(ref, query)

def remove_singletons(cluster_to_sample: dict):
    """Remove clusters with only one sample"""
    multi_sample_clusters_to_sample = cluster_to_sample.copy()
    for cluster, samples in cluster_to_sample.items():
        if len(samples) == 1:
            logging.warning(f"Cluster {cluster} has only one sample, removing from analysis")
            del multi_sample_clusters_to_sample[cluster]
    return multi_sample_clusters_to_sample

def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

def main():
    args = parse_arguments()
    setup_logging()

    args.outdir.mkdir(parents=True, exist_ok=True)
    
    # Read the matrix and cluster information
    references = read_references(args.references)
    references = list(references)
    cluster_to_sample = read_clusters(args.clusters, args.header)
    cluster_to_sample = remove_singletons(cluster_to_sample)
    matrix = read_matrix(args.matrix)

    for cluster, samples in cluster_to_sample.items():
        cluster_dists = defaultdict(list)
        ref_query_generator = iterDistRows(references, references, self=True)
        for i, (ref, query) in enumerate(ref_query_generator):
            if ref in samples and query in samples:
                cluster_dists["sample"].append(query)
                cluster_dists["reference"].append(ref)
                cluster_dists["core_dist"].append(matrix[i,0])
                cluster_dists["acc_dist"].append(matrix[i,1])
        cluster_dists = pd.DataFrame(cluster_dists)
        cluster_dists.to_csv(args.outdir / f"{cluster}_distances.tsv", sep='\t', index=False)

if __name__ == "__main__":
    main()