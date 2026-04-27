#!/usr/bin/env python3
"""
Create a CSV mapping FASTA reference file paths to reference labels.

Input:
    A text file containing one reference FASTA path per line.

Output CSV columns:
    ref_label,reference_path
"""

import argparse
import logging
import re
from pathlib import Path
from typing import Iterable, List

import pandas as pd


LOGGER = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate CSV of ref_label,reference_path from FASTA paths."
    )
    parser.add_argument(
        "--references",
        type=Path,
        help="Text file containing one FASTA reference path per line.",
    )
    parser.add_argument(
        "--output_csv",
        type=Path,
        help="Output CSV path.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging level (default: INFO).",
    )
    return parser.parse_args()


def setup_logging(level: str) -> None:
    """Configure logging."""
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format="%(asctime)s %(levelname)s %(message)s",
    )


def make_ref_label(reference_path: str) -> str:
    """
    Convert a FASTA path into a reference label.

    Current behaviour imitates ref_label extraction of poppunk:
      1. Extract filename
      2. Remove suffix, e.g. '.gz'
      3. Replace dots with underscores

    Example:
        GCA_035419305.1_ASM3541930v1_genomic.fna.gz
        -> GCA_035419305_1_ASM3541930v1_genomic_fna
    """
    stem = Path(reference_path).stem
    label = re.sub(r"[.]", "_", stem)
    return label


def read_reference_paths(references: Path) -> List[str]:
    """Read non-empty stripped lines from input file."""
    LOGGER.info("Reading reference paths from %s", references)

    with references.open("r", encoding="utf-8") as handle:
        paths = [line.strip() for line in handle if line.strip()]

    LOGGER.info("Loaded %d reference paths", len(paths))
    return paths


def build_dataframe(reference_paths: Iterable[str]) -> pd.DataFrame:
    """Build pandas DataFrame with ref_label and reference_path columns."""
    records = []

    for path in reference_paths:
        ref_label = make_ref_label(path)
        records.append(
            {
                "ref_label": ref_label,
                "reference_path": path,
            }
        )

    df = pd.DataFrame(records, columns=["ref_label", "reference_path"])
    LOGGER.info("Created dataframe with %d rows", len(df))
    return df


def write_csv(df: pd.DataFrame, output_csv: Path) -> None:
    """Write DataFrame to CSV."""
    LOGGER.info("Writing CSV to %s", output_csv)
    df.to_csv(output_csv, index=False)
    LOGGER.info("Finished writing CSV")


def main() -> None:
    """Main entry point."""
    args = parse_args()
    setup_logging(args.log_level)

    reference_paths = read_reference_paths(args.references)
    df = build_dataframe(reference_paths)
    write_csv(df, args.output_csv)


if __name__ == "__main__":
    main()
