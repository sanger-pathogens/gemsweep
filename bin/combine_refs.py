#!/usr/bin/env python3

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Combine references and groups to preserve group identity."
    )
    parser.add_argument(
        "--refs",
        help="Path to file containing list of reference files to combine.",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--groups",
        help="Path to file containing list of groups files to combine (same order as --refs file).",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--prefix_groups",
        help="Prefix groups with names derived from the group files.",
        action="store_true",
    )
    parser.add_argument("--outdir", type=Path, default=".")
    return parser.parse_args()


def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def load_data(filepath: Path) -> pd.DataFrame:
    df = pd.read_csv(filepath, header=None)
    return df


def get_filepath_list(manifest: Path) -> list[Path]:
    errors = 0
    manifest_filepaths = []
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
            manifest_filepaths.append(filepath)
    if errors:
        logging.error(
            f"Detected {errors} errors during parsing of {manifest}. Exiting now"
        )
        sys.exit(1)
    return manifest_filepaths


def get_df_list(filepaths: list[Path]) -> list[pd.DataFrame]:
    return [load_data(filepath) for filepath in filepaths]


def get_group_prefix_from_files(filepaths: list[Path]) -> list[str]:
    return [f"{filepath.stem}_" for filepath in filepaths]


def combine_dfs(dfs: list[pd.DataFrame]) -> pd.DataFrame:
    return pd.concat(dfs, ignore_index=True)


def combine_groups(groups_dfs: list[pd.DataFrame], group_prefixes: list[str] = None) -> pd.DataFrame:
    combined_groups = pd.DataFrame()
    if group_prefixes:
        dfs_to_combine = [prefix + group.astype(str) for prefix, group in zip(group_prefixes, groups_dfs)]
        combined_groups = pd.concat(dfs_to_combine, ignore_index=True)
    else:
        for groups_df in enumerate(groups_dfs):
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

    refs_paths = get_filepath_list(args.refs)
    groups_paths = get_filepath_list(args.groups)
    refs = get_df_list(refs_paths)
    groups = get_df_list(groups_paths)

    combined_refs = combine_dfs(refs)

    if args.prefix_groups:
        groups_prefixes = get_group_prefix_from_files(refs_paths)
        combined_groups = combine_groups(groups, groups_prefixes)
    else:
        combined_groups = combine_groups(groups)

    combined_refs.to_csv(args.outdir / "references.txt", index=False, header=False)
    combined_groups.to_csv(args.outdir / "groups.txt", index=False, header=False)


if __name__ == "__main__":
    main()
