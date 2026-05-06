#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path
from typing import Tuple

import pandas as pd


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Join labels, reference paths, and clusters into ordered outputs.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument(
        "--ref_labels",
        type=Path,
        required=True,
        help="File containing one label per line in desired output order",
    )

    parser.add_argument(
        "--reference_list",
        type=Path,
        required=True,
        help="CSV file: label,reference_path",
    )

    parser.add_argument(
        "--clusters_csv",
        type=Path,
        required=True,
        help="CSV file: label,cluster",
    )

    parser.add_argument(
        "--output_prefix",
        type=str,
        default="output",
        help="Prefix for output files",
    )

    parser.add_argument(
        "--log_level",
        type=str,
        default="INFO",
        help="Logging level",
    )

    return parser.parse_args()


def setup_logging(level: str) -> None:
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format="%(asctime)s - %(levelname)s - %(message)s",
    )


def load_labels(path: Path) -> pd.DataFrame:
    labels = pd.read_csv(path, header=None, names=["label"], dtype=str)
    labels["order"] = range(len(labels))
    return labels


def load_reference_list(path: Path) -> pd.DataFrame:
    return pd.read_csv(
        path,
        header=0,
        names=["label", "reference_path"],
        dtype=str,
    )


def load_clusters(path: Path) -> pd.DataFrame:
    return pd.read_csv(
        path,
        header=0,
        names=["label", "cluster"],
        dtype=str,
    )


def join_tables(
    labels_df: pd.DataFrame,
    refs_df: pd.DataFrame,
    clusters_df: pd.DataFrame,
) -> pd.DataFrame:

    df = labels_df.merge(refs_df, on="label", how="left")
    df = df.merge(clusters_df, on="label", how="left")

    missing_refs = df["label"][df["reference_path"].isna()]
    missing_clusters = df["label"][df["cluster"].isna()]

    if missing_refs:
        logging.warning(f"Missing reference_path for the following labels: {list(missing_refs})")
        logging.warning(f"Missing reference_path for {len(missing_refs)} labels")

    if missing_clusters:
        logging.warning(f"Missing clusters for the following labels: {list(missing_clusters})")
        logging.warning(f"Missing cluster for {len(missing_clusters)} labels")

    df = df.sort_values("order").drop(columns=["order"])

    return df


def write_outputs(df: pd.DataFrame, prefix: str) -> Tuple[Path, Path, Path]:
    joined = Path(f"{prefix}_reference_clusters.csv")
    refs = Path(f"{prefix}_references.txt")
    clusters = Path(f"{prefix}_clusters.txt")

    df.to_csv(joined, index=False)

    df["reference_path"].to_csv(refs, index=False, header=False)
    df["cluster"].to_csv(clusters, index=False, header=False)

    return joined, refs, clusters


def main() -> None:
    args = parse_args()
    setup_logging(args.log_level)

    logging.info("Loading input files")

    labels_df = load_labels(args.ref_labels)
    refs_df = load_reference_list(args.reference_list)
    clusters_df = load_clusters(args.clusters_csv)

    logging.info("Joining tables")

    joined_df = join_tables(labels_df, refs_df, clusters_df)

    joined, refs, clusters = write_outputs(joined_df, args.output_prefix)

    logging.info("Wrote %s", joined)
    logging.info("Wrote %s", refs)
    logging.info("Wrote %s", clusters)


if __name__ == "__main__":
    main()
