#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Combine references and groups to preserve group identity."
    )
    parser.add_argument(
        "--ref_group_files",
        help="Path to files containing list of reference files to combine.",
        nargs="+",
        type=Path,
        required=True,
    )
    parser.add_argument(
<<<<<<< HEAD
        "--prefix_groups",
        help="Prefix groups with names derived from the group files.",
=======
        "--header",
        help="Header present on input files.",
>>>>>>> 76de388 (python script:)
        action="store_true",
    )
    parser.add_argument(
        "--header",
        help="Header present on input files.",
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


def load_data(filepath: Path, header: bool = True) -> pd.DataFrame:
<<<<<<< HEAD
=======
    # Read a ref/group CSV and sort by label so refs and groups stay aligned.
>>>>>>> 76de388 (python script:)
    if header:
        df = pd.read_csv(filepath, header=0, names=["label", "ref", "group"])
    else:
        df = pd.read_csv(filepath, header=None, names=["label", "ref", "group"])
<<<<<<< HEAD
    return df
=======
    return df.sort_values("label", kind="stable")
>>>>>>> 76de388 (python script:)


def get_group_prefix_from_files(filepaths: list[Path]) -> list[str]:
    # Use each input filename as the prefix for provenance-preserving groups.
    return [f"{filepath.stem}_" for filepath in filepaths]


def combine_dfs(dfs: list[pd.DataFrame]) -> pd.DataFrame:
    # Stack all reference rows into one output table.
    return pd.concat(dfs, ignore_index=True)


<<<<<<< HEAD
def combine_groups(groups_dfs: list[pd.DataFrame], group_prefixes: list[str] = None) -> pd.DataFrame:
    combined_groups = pd.DataFrame()
    if group_prefixes:
        dfs_to_combine = [prefix + group.astype(str) for prefix, group in zip(group_prefixes, groups_dfs)]
        combined_groups = pd.concat(dfs_to_combine, ignore_index=True)
    else:
        for groups_df in groups_dfs:
            if combined_groups.empty:
                combined_groups = groups_df
            else:
                max_group = combined_groups.max()
                groups_df = groups_df + max_group
                combined_groups = pd.concat([combined_groups, groups_df], ignore_index=True)
    return combined_groups
=======
def combine_prefixed_groups(
    groups: list[pd.Series], group_prefixes: list[str]
) -> pd.DataFrame:
    # Prefix group IDs before combining to avoid collisions between input files.
    prefixed_groups = [
        prefix + group.astype(str)
        for prefix, group in zip(group_prefixes, groups)
    ]
    return pd.concat(prefixed_groups, ignore_index=True).to_frame()
>>>>>>> 76de388 (python script:)


def main() -> None:
    args = parse_args()
    setup_logging()

<<<<<<< HEAD
    ref_group_dfs = [load_data(filepath, header=args.header) for filepath in args.ref_group_files]

=======
    # Load each input file as label/ref/group records.
    ref_group_dfs = [
        load_data(filepath, header=args.header)
        for filepath in args.ref_group_files
    ]

    # Split refs and groups after sorting by label.
>>>>>>> 76de388 (python script:)
    refs = []
    groups = []
    for ref_group_df in ref_group_dfs:
        refs.append(ref_group_df["ref"])
        groups.append(ref_group_df["group"])

    combined_refs = combine_dfs(refs)
<<<<<<< HEAD

    if args.prefix_groups:
        groups_prefixes = get_group_prefix_from_files(args.ref_group_files)
        combined_groups = combine_groups(groups, groups_prefixes)
    else:
        combined_groups = combine_groups(groups)
=======
    # Preserve source identity directly in group names.
    groups_prefixes = get_group_prefix_from_files(args.ref_group_files)
    combined_groups = combine_prefixed_groups(groups, groups_prefixes)
>>>>>>> 76de388 (python script:)

    combined_refs.to_csv(args.outdir / "references.txt", index=False, header=False)
    combined_groups.to_csv(args.outdir / "groups.txt", index=False, header=False)


if __name__ == "__main__":
    main()
