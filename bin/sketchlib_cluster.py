#!/usr/bin/env python3

"""
Cluster genomes in a pre-sketched sketchlib database by pairwise ANI distance
using connected components. Outputs a CSV mapping each genome ID to a cluster ID.

Example usage:
    ./sketchlib_cluster.py \
        --sketch <pre-sketched_refs> \
        --ani_threshold 0.05 \
        --ref_ids <path/to/refs_ids.txt> \
        --kmer_size 17 \
        --out .

"""

from pathlib import Path
import sys
import logging
import pp_sketchlib
# import numpy as np
import scipy.sparse.csgraph as csgraph
import scipy.sparse as sp
import pandas as pd
import argparse

def main():
    args = parse_args()
    setup_logging(args.log, args.debug)

    # Load genome names
    with open(args.ref_ids) as f:
        ref_ids = [line.strip() for line in f]

    klist = args.klist
    logging.info(f"Using kmer lengths: {klist}")

    # Query pairwise distances using ANI (single k-mer = no core/accessory decomposition)
    # querySelfSparse returns a tuple of three lists (rows, cols, dists) — only distances BELOW threshold
    # Avoids a full/dense n^2 matrix which would be slow for large reference sets
    rows, cols, dists = pp_sketchlib.querySelfSparse(
        ref_db_name    = args.sketch,
        rList          = ref_ids,
        klist          = args.klist,
        random_correct = True,
        dist_cutoff    = args.ani_threshold,  # only return pairs below this distance
        jaccard        = False,              # return ANI distance, not raw Jaccard
        num_threads    = args.threads,
        use_gpu        = False,
        device_id      = 0,
        kNN            = 0,
        dist_col       = 0
    )

    # Convert returned tuple of lists to a COO matrix
    l = len(ref_ids)
    coo = sp.coo_matrix((dists, (rows, cols)), shape=(l, l))

    # Convert to compressed sparse row (CSR) format for connected_components
    csr = coo.tocsr()

    # Connected components = clusters
    # Any two genomes connected by distance < threshold end up in the same cluster
    n_components, labels = csgraph.connected_components(
        csgraph  = csr,
        directed = False
    )

    df = pd.DataFrame({'genome_id': ref_ids, 'cluster_id': labels})

    # Trigger exit pipeline if in strict mode i.e. cluster check failures stop pipeline there
    num_refs = len(ref_ids)
    validated = validate_clusters(clusters_df=df, num_refs=num_refs, ani_threshold=args.ani_threshold)
    if not validated and args.strict_mode:
        sys.exit(1)
    
    # Write output
    df.to_csv(args.out, sep=',', index=False)
    logging.info(f"Assigned {len(ref_ids)} genomes to {n_components} clusters")

def validate_log_filename(log_filename:str):
    if not log_filename:
        raise ValueError("Log file name cannot be empty.")
    if " " in log_filename:
        raise ValueError(f"Log file name '{log_filename}' must not contain spaces.")
    if "/" in log_filename or "\\" in log_filename:
        raise ValueError(f"Log file name '{log_filename}' must be a string, no path separators allowed.")

def setup_logging(log_filename: str, debug:bool):
    validate_log_filename(log_filename)
    if not log_filename.endswith(".log"):
        log_filename += ".log"
    
    if debug:
        logging.basicConfig(
        level=logging.DEBUG,
        handlers=[logging.StreamHandler(), logging.FileHandler(log_filename, mode="w")],
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    else:
        logging.basicConfig(
        level=logging.INFO,
        handlers=[logging.StreamHandler(), logging.FileHandler(log_filename, mode="w")],
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    logging.info("Logging initialized.")

def parse_args() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Pairwise ANI distance-based connected components clustering.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--debug", 
        action='store_true',
        required=False, 
        default=False,
        help="Set to true to log debug-level information"
    )
    parser.add_argument(
        "--log", 
        type=str, 
        required=False, 
        default=f"{Path(sys.argv[0]).stem}",
        help="Basename of the log file, e.g. --log foo will ouput foo.log"
    )
    parser.add_argument(
        "--sketch", 
        type=str, 
        required=True, 
        help="Sketchlib db path up including prefix but not extensions for .skm and .skd files"
    )
    parser.add_argument(
        "--ani_threshold",
        type=float,
        default=0.05,
        help="ANI distance threshold for clustering (default 0.05, clusters of 95% ANI)"
    )
    parser.add_argument(
        "--ref_ids",
        type=Path,
        required=True,
        help="Text file list of references, one ID per line in same order as supplied for sketch."
    )
    parser.add_argument(
        "--klist",
        type=int,
        nargs='+',
        default=[13, 17, 21, 25, 29],    # Matches PopPUNK default
        help="Kmer lengths to use for computing ANI"
    )
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Name for the output CSV"
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=1,
        help="Number of threads to use."
    )
    parser.add_argument(
        "--strict_mode",
        action='store_true',
        help="Turn on to produce exit code 1 on failure of cluster checks."
    )
    return parser.parse_args()

def validate_clusters(clusters_df: pd.DataFrame, num_refs: int, ani_threshold: float) -> bool:
    checks_passed = True

    cluster_counts = clusters_df['cluster_id'].value_counts()
    num_clusters = len(cluster_counts)

    if num_clusters == 1:
        logging.error(f"All {num_refs} references in a single cluster - ANI threshold of {ani_threshold} is likely too high")
        checks_passed=False

    if num_clusters == num_refs:
        logging.error(f"Each reference is in it's own cluster - ANI threshold of {ani_threshold} is likely too low")
        checks_passed=False

    return checks_passed

if __name__ == "__main__":
    main()
