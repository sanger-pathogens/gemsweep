#!/usr/bin/env python3

"""
Cluster genomes in a pre-sketched sketchlib database by pairwise ANI distance 
using connected components. Outputs a CSV mapping each genome ID to a cluster 
ID. Also performs cluster checks; if each genome is in its own cluster or all 
genomes fall into a single cluster, log a warning or, in strict mode, exit with
nonzero exit code.

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

ALGORITHMS = {
    "connected_components": None,  # handled separately — not a community method
    "leiden":               lambda g: g.community_leiden(objective_function="modularity", weights="weight"),
    "louvain":              lambda g: g.community_multilevel(weights="weight"),
    "walktrap":             lambda g: g.community_walktrap(weights="weight").as_clustering(),
    "fastgreedy":           lambda g: g.community_fastgreedy(weights="weight").as_clustering(),
    "label_propagation":    lambda g: g.community_label_propagation(weights="weight"),
    "infomap":              lambda g: g.community_infomap(edge_weights="weight"),
    "spinglass":            lambda g: g.community_spinglass(weights="weight"),
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

    # Convert returned tuple of lists to a COO matrix
    l = len(ref_ids)
    coo = sp.coo_matrix((dists, (rows, cols)), shape=(l, l))

    # Convert to compressed sparse row (CSR) format for connected_components
    csr = coo.tocsr()

    # Connected components = clusters
    # Any two genomes connected by distance < threshold end up in the same cluster
    logging.info("Forming clusters of references connected by the returned distances...")
    n_components, labels = csgraph.connected_components(
        csgraph  = csr,
        directed = False
    )

    df = pd.DataFrame({'genome_id': ref_ids, 'cluster_id': labels})

    # Trigger exit pipeline if in strict mode i.e. cluster check failures stop pipeline there
    logging.info("Validating clusters...")
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
        help="Sketchlib db path including prefix but not extensions for .h5 file"
    )
    parser.add_argument(
        "--ani_threshold",
        type=float,
        default=0.02,
        help="maximum ANI distance threshold for clustering (default 0.02, meaning clusters of genomes sharing at least 98%% ANI similarity)"
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
        "--out",
        type=Path,
        required=True,
        help="Path to save the output CSV"
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

if __name__ == "__main__":
    main()
