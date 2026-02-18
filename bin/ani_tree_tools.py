#!/usr/bin/env python3

# Code written by John Lees and adapted for purpose here###

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

from tree_builder import generate_phylogeny


def read_tsv_to_structures(filepath: str) -> tuple[list[str], np.ndarray]:
    """
    Read a TSV file containing pairwise ANI values and convert to a
    distance matrix.

    Args:
        filepath: Path to TSV file with columns: sample, reference, ani

    Returns:
        Tuple containing:
        - List of unique sample/reference names
        - Square numpy array of distance values
    """
    try:
        df = pd.read_csv(filepath,
                         sep="\t",
                         names=["sample", "reference", "ani"])

        # get the uniques and store them indexed to map to the df
        unique_ids = pd.unique(pd.concat([df["sample"], df["reference"]]))
        id_to_idx = {name: idx for idx, name in enumerate(unique_ids)}

        df["sample_idx"] = df["sample"].map(id_to_idx)
        df["reference_idx"] = df["reference"].map(id_to_idx)

        # Vectorized conversion of ANI to distance
        df["distance"] = 1 - df["ani"]

        # Initialize distance matrix
        n = len(unique_ids)
        dist_mat = np.zeros((n, n), dtype=np.float32)

        dist_mat[df["sample_idx"], df["reference_idx"]] = df["distance"]

        return list(unique_ids), dist_mat

    except Exception as e:
        raise ValueError(f"Error processing TSV file: {str(e)}")


def read_tsv_to_core_accession(filepath: str
                               ) -> tuple[list[str], np.ndarray, np.ndarray]:
    """
    Read a TSV file containing pairwise core and accessory distances and
    convert to distance matrices.

    Args:
        filepath: Path to TSV file with columns:
        sample, reference, core_dist, acc_dist

    Returns:
        Tuple containing:
        - List of unique sample/reference names
        - Core distance matrix (numpy array)
        - Accessory distance matrix (numpy array)
    """
    try:
        # Read TSV into DataFrame
        df = pd.read_csv(filepath,
                         sep="\t",
                         names=["sample",
                                "reference",
                                "core_dist",
                                "acc_dist"])

        # Get unique identifiers while preserving order of first appearance
        unique_ids = pd.unique(pd.concat([df["sample"], df["reference"]]))
        id_to_idx = {name: idx for idx, name in enumerate(unique_ids)}

        # Vectorized creation of index arrays using the mapping
        df["sample_idx"] = df["sample"].map(id_to_idx)
        df["reference_idx"] = df["reference"].map(id_to_idx)

        n = len(unique_ids)

        # Initialize distance matrices
        core_dist_mat = np.zeros((n, n))
        acc_dist_mat = np.zeros((n, n))

        # fill the core matrix
        core_dist_mat[df["sample_idx"], df["reference_idx"]] = df["core_dist"]
        core_dist_mat[df["reference_idx"], df["sample_idx"]] = df["core_dist"]

        # now accessory
        acc_dist_mat[df["sample_idx"], df["reference_idx"]] = df["acc_dist"]
        acc_dist_mat[df["reference_idx"], df["sample_idx"]] = df["acc_dist"]

        return list(unique_ids), core_dist_mat, acc_dist_mat

    except Exception as e:
        raise ValueError(f"Error processing TSV file: {str(e)}")


def generate_phylip_matrix(ref_list: list[str],
                           matrix: np.ndarray,
                           meta_id: str) -> str:
    """
    Generate a Phylip format distance matrix file.

    Args:
        ref_list: List of reference names
        matrix: Square distance matrix
        meta_id: Identifier for output filename

    Returns:
        Absolute path to generated Phylip file
    """
    if len(ref_list) != matrix.shape[0] or matrix.shape[0] != matrix.shape[1]:
        raise ValueError(
            "Matrix dimensions do not match reference list length"
            )

    output_path = Path(f"{meta_id}_distances.phylip").absolute()

    try:
        with open(output_path, "w") as f:
            f.write(f"{len(ref_list)}\n")

            for ref, distances in zip(ref_list, matrix):

                # Format distances with consistent precision
                formatted_distances = " ".join(str(d) if d != 0.0
                                               else "0.0" for d in distances)

                f.write(f"{ref} {formatted_distances}\n")

        return str(output_path)

    except IOError as e:
        raise IOError(f"Error writing Phylip file: {str(e)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process input files")
    parser.add_argument(
        "-r", "--dist_tsv_path",
        type=str, required=True,
        help="Input TSV file with Reference pairwise ANI data"
    )
    parser.add_argument(
        "--meta_ID",
        type=str,
        required=True,
        help="ID of dataset")
    parser.add_argument(
        "--build_tree",
        action="store_true",
        help="Option to build tree")
    parser.add_argument(
        "--phylip_path",
        type=str,
        help="Optional: Pre-generated PHYLIP file path")
    parser.add_argument(
        "--core_accession",
        action="store_true",
        help="parse input TSV as core + accession rather than single ANI scores",
    )
    args = parser.parse_args()

    if args.phylip_path:
        phylip_path = args.phylip_path
        sys.stderr.write(f"Using provided PHYLIP file: {phylip_path}\n")
    else:
        # Read the TSV and process data
        if args.core_accession:
            ref_list, dist_mat, _ = read_tsv_to_core_accession(args.dist_tsv_path)
        else:
            ref_list, dist_mat = read_tsv_to_structures(args.dist_tsv_path)

        # Generate the PHYLIP matrix
        phylip_path = generate_phylip_matrix(ref_list, dist_mat, args.meta_ID)

    # Conditionally build the tree if --build_tree is specified
    if args.build_tree:
        generate_phylogeny(phylip_path, args.meta_ID, "nwk", True)
    else:
        sys.stderr.write("Skipping tree generation\n")
