#!/usr/bin/env python3

"""
Cluster genomes in a pre-sketched sketchlib database by pairwise ANI distance
using clustering/ community-finding algorithm of choice. Outputs a CSV mapping
each genome ID to a cluster ID. Also sanity checks clusters; if each genome
is in it's own cluster or all genomes fall into a single cluster, it either logs
a warning or, in strict mode, fails with a non-zero exit code.

Example usage:
    sketchlib_cluster.py \
        --sketch reference_sketch \
        --ani_threshold 0.01 \
        --ref_ids path/to/refs_ids.txt \
        --kstep 17,20,1 \
        --out . \
        --strict_mode

"""

from pathlib import Path
import sys
import logging
import pp_sketchlib
import igraph as ig
import pandas as pd
import argparse
import numpy as np

ALGORITHMS = {
    "connected_components": None,  # handled separately — not a community method, needed here for argparse
    "leiden":               lambda g: g.community_leiden(objective_function="modularity", weights="weight"),
    "louvain":              lambda g: g.community_multilevel(weights="weight"),
    "walktrap":             lambda g: g.community_walktrap(weights="weight").as_clustering(),
    "fastgreedy":           lambda g: g.community_fastgreedy(weights="weight").as_clustering(),
    "label_propagation":    lambda g: g.community_label_propagation(weights="weight"),
    "infomap":              lambda g: g.community_infomap(edge_weights="weight"),
#    "spinglass":            lambda g: g.community_spinglass(weights="weight"), # graph connectivity after sparse query might be an issue
    "eigenvector":          lambda g: g.community_leading_eigenvector(weights="weight"),
}

def main():
    args = parse_args()
    setup_logging(args.log, args.debug)

    logging.info("Loading reference genomes...")
    # Load genome names
    with open(args.ref_ids) as f:
        ref_ids = [line.strip() for line in f]

    klist = parse_kmer_sizes(args.kstep)
    logging.info(f"Using kmer lengths: {klist}")

    # Query pairwise distances using ANI (single k-mer = no core/accessory decomposition)
    # querySelfSparse returns a tuple of three lists (rows, cols, dists) — only distances BELOW threshold
    # Avoids a full/dense n^2 matrix which would be slow for large reference sets
    logging.info(f"Querying sketch to return pairs with distances below {args.ani_threshold}...")
    rows, cols, dists = pp_sketchlib.querySelfSparse(
        ref_db_name    = args.sketch,
        rList          = ref_ids,
        klist          = klist,
        random_correct = args.random_correct,
        dist_cutoff    = args.ani_threshold,  # only return pairs below this distance
        jaccard        = False,              # return ANI distance, not raw Jaccard
        num_threads    = args.threads,
        use_gpu        = False,
        device_id      = 0,
        kNN            = 0,
        dist_col       = 0
    )
    logging.debug(f"Distance stats: min={min(dists):.6f}, max={max(dists):.6f}, mean={sum(dists)/len(dists):.6f}")

    # Build a graph of the sparse sketchlib output (returned ANIs as edges)
    logging.info("Building graph from pairwise distances...")
    edges = list(zip(rows,cols))
    weights = [1.0 - d for d in dists] # Community algos expect similarity not distance
    g = ig.Graph(
        n = len(ref_ids),
        edges = edges,
        directed = False
    )
    g.vs["name"] = ref_ids
    g.es["weight"] = weights

    # Find communities/ clusters
    logging.info(f"Running community detection with algorithm: '{args.algorithm}'...")
    labels = run_clustering(g, args.algorithm)

    df = pd.DataFrame({'genome_id': ref_ids, 'cluster_id': labels})

    # Trigger exit pipeline if in strict mode i.e. cluster check failures stop pipeline there
    logging.info("Validating clusters...")
    num_refs = len(ref_ids)
    validated = validate_clusters(clusters_df=df, num_refs=num_refs, ani_threshold=args.ani_threshold)
    if not validated and args.strict_mode:
        sys.exit(1)
    
    # Write outputs
    df.to_csv(f"{args.out_prefix}_clusters.csv", sep=',', index=False)
    n_components = len(g.clusters(mode="weak"))
    n_communities = len(set(labels))
    logging.info(f"Graph has {len(ref_ids)} genomes in {n_components} connected components, "
                 f"further split into {n_communities} communities by {args.algorithm}")

    save_dist_matrix(
        num_refs=len(ref_ids),
        rows = rows,
        cols = cols,
        dists = dists,
        out_prefix= args.out_prefix
    )

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
        description="Perform clustering/ community-finding using pairwise ANI distances.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--debug", 
        action='store_true',
        help="Enable logging of debug-level information"
    )
    parser.add_argument(
        "--log", 
        type=str,
        default=f"{Path(sys.argv[0]).stem}",
        help="Basename of the log file, e.g. --log foo will ouput foo.log"
    )
    parser.add_argument(
        "--sketch", 
        type=str, 
        required=True, 
        help="Sketchlib db path including prefix but not extensions for .h5 file"
    )
    parser.add_argument(
        "--ani_threshold",
        type=float,
        default=0.02,
        help="Maximum ANI distance threshold for clustering (default 0.02, meaning clusters of genomes sharing at least 98%% ANI similarity)"
    )
    parser.add_argument(
        "--ref_ids",
        type=Path,
        required=True,
        help="Text file list of references, one ID per line in same order as supplied for sketch"
    )
    parser.add_argument(
        "--kstep",
        type=str,
        default="13,29,4",    # Matches PopPUNK default
        help="Kmer lengths to use for computing ANI in the format start,stop,step"
    )
    parser.add_argument(
        "--out_prefix",
        type=str,
        required=True,
        help="Name for output files."
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=1,
        help="Number of threads to use"
    )
    parser.add_argument(
        "--strict_mode",
        action='store_true',
        help="Produce exit code 1 on failure of cluster checks"
    )
    parser.add_argument(
        "--random_correct",
        action='store_true',
        help="Apply random match correction. Only use if sketch includes random match calculations."
    )
    parser.add_argument(
        "--algorithm",
        type=str,
        default="connected_components",
        choices=list(ALGORITHMS),
        help="Community detection algorithm to use"
    )
    return parser.parse_args()

def parse_kmer_sizes(kstep: str) -> list[int]:
    parsed_k = kstep.split(',')
    k_start = int(parsed_k[0])
    k_stop = int(parsed_k[1])
    step = int(parsed_k[2])

    kmer_sizes = list(range(k_start, k_stop + 1, step))

    return kmer_sizes

def run_clustering(graph: ig.Graph, algorithm: str) -> list[int]:
    # In the case of connected components there is no partition
    if algorithm == "connected_components":
        membership = graph.clusters(mode="weak").membership
        return membership
    community_fn = ALGORITHMS[algorithm]
    partition = community_fn(graph)
    return partition.membership

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

    logging.debug(f"Cluster sizes:\n{cluster_counts.to_string()}")

    return checks_passed

def upper_triangle_index(i: int, j: int, n: int) -> int:
    '''Return the row index in a long-form upper triangle array for pair (i, j).
    
    Assumes i < j. For an n x n matrix, the upper triangle has n*(n-1)//2 
    entries stored row by row, left to right, excluding the diagonal.
    '''
    return i * n - i * (i + 1) // 2 + j - i - 1

def save_dist_matrix(num_refs: int, rows: list[int], cols: list[int], dists: list[float], out_prefix: str):
    '''Replicates the *.dists.npy poppunk output but with notable exceptions:
      a) NaNs to fill distances missing due to the sparse query
      b) Only a single set of dists (one column), no core and accessory'''
    
    n_pairs = num_refs * (num_refs - 1) // 2

    dist_matrix = np.full((n_pairs, 1), np.nan) # Change to 2 columns if replicating poppunk format

    for i, j, d in zip(rows, cols, dists):
        if i < j:
            idx = upper_triangle_index(i, j, num_refs)
            dist_matrix[idx, 0] = d
#            dist_matrix[idx, 1] = d second column identical if necessary to replicate 2 col format of poppunk

    np.save(out_prefix + ".dists.npy", dist_matrix)
    logging.info(f"Saved distance matrix to {out_prefix}.dists.npy")

if __name__ == "__main__":
    main()
