#!/usr/bin/env python3

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(description="Combine references and groups to preserve group identity.")
    parser.add_argument("--refs", help="Path to file containing list of reference files to combine.", type=Path, required=True)
    parser.add_argument("--groups", help="Path to file containing list of groups files to combine (same order as --refs file).", type=Path, required=True)
    parser.add_argument("--outdir", type=Path, default=".")
    return parser.parse_args()


def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def load_data(filepath: Path) -> pd.DataFrame:
    df = pd.read_csv(filepath, header=None)
    return df


def get_df_list(manifest: Path) -> list[pd.DataFrame]:
    dfs = []
    errors = 0
    with open(manifest) as f:
        for line in f:
            filepath = line.strip()
            if not filepath:
                continue
            filepath = Path(filepath)
            if not filepath.is_file():
                logging.error(f"Filepath in {manifest} is not a file: {filepath}")
                errors += 1
                continue
            dfs.append(load_data(filepath))
    if errors:
        logging.error(f"Detected {errors} errors during parsing of {manifest}. Exiting now")
        sys.exit(1)
    return dfs


def combine_dfs(dfs: list[pd.DataFrame]) -> pd.DataFrame:
    return pd.concat(dfs, ignore_index=True)


def combine_groups(groups_dfs: list[pd.DataFrame]) -> pd.DataFrame:
    combined_groups = pd.DataFrame()
    for groups_df in groups_dfs:
        if combined_groups.empty:
            combined_groups = groups_df
        else:
            max_group = combined_groups.max()
            groups_df = groups_df + max_group
            combined_groups = pd.concat([combined_groups, groups_df], ignore_index=True)
    return combined_groups


def main():
    args = parse_args()
    setup_logging()

    refs = get_df_list(args.refs)
    groups = get_df_list(args.groups)

    combined_refs = combine_dfs(refs)
    combined_groups = combine_groups(groups)

    combined_refs.to_csv(args.outdir / "references.txt", index=False, header=False)
    combined_groups.to_csv(args.outdir / "groups.txt", index=False, header=False)

if __name__ == "__main__":
    main()