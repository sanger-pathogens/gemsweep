#!/usr/bin/env python3

"""
Write one generated species reference entry into the configured cache.

The script reads cache_config.json from CACHE_RESOLVE, checks write_cache, and
writes generated references/groups and combined reference cluster CSVs to:

  write_cache_dir/species/<species_id>/

write_cache_dir is always the user's read-write cache. The admin-managed
read-only cache is never written to by this script.

Cache entries are immutable. If a complete entry already exists it is left
unchanged (with a warning); if only some of its files exist the script exits
with an error. The entry's metadata.json records the configuration, creation
time, and reference IDs. Top-level cache metadata is not updated here to avoid
concurrent writes from multiple species tasks.
"""

import argparse
import csv
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Write a generated species entry into the reference cache.")
    parser.add_argument("--species", required=True, help="Species or taxon identifier.")
    parser.add_argument("--refs", type=Path, required=True, help="Generated references.txt for this species.")
    parser.add_argument("--groups", type=Path, required=True, help="Generated groups.txt for this species.")
    parser.add_argument("--reference-clusters", type=Path, required=True, help="Generated CSV for this species with header 'label,reference_path,cluster'.")
    parser.add_argument("--cache-config", type=Path, required=True, help="cache_config.json from CACHE_RESOLVE.")
    return parser.parse_args()


def read_json(path: Path) -> dict:
    with open(path) as in_f:
        return json.load(in_f)


def write_json(path: Path, data: dict):
    with open(path, "w") as out_f:
        json.dump(data, out_f, indent=2, sort_keys=True)
        out_f.write("\n")


def read_lines(path: Path) -> list[str]:
    with open(path) as in_f:
        return [line.rstrip("\n") for line in in_f]


def validate_line_counts(refs: list[str], groups: list[str], refs_file: Path, groups_file: Path):
    if len(refs) != len(groups):
        raise SystemExit(
            f"Cannot write cache entry: {refs_file} has {len(refs)} lines but "
            f"{groups_file} has {len(groups)} lines."
        )


def cache_entry_paths(
    cache_config: dict, species: str
) -> tuple[Path, Path, Path, Path, Path]:
    species_dir = Path(cache_config["write_cache_dir"]) / "species" / species
    return (
        species_dir,
        species_dir / "references.txt",
        species_dir / "groups.txt",
        species_dir / f"{species}_reference_clusters.csv",
        species_dir / "metadata.json",
    )

def reference_id(reference: str) -> str:
    name = Path(reference).name
    for suffix in [".gz", ".fna", ".fasta", ".fa", ".ffn", ".faa"]:
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def update_metadata(
    metadata_file: Path,
    cache_config: dict,
    species: str,
    reference_ids: list[str],
):
    write_json(
        metadata_file,
        {
            "species_id": species,
            "cluster_method": cache_config.get("cluster_method"),
            "representatives": cache_config.get("representatives"),
            "db": cache_config.get("db"),
            "n_references": len(reference_ids),
            "reference_ids": reference_ids,
            "created_at": datetime.now(timezone.utc).isoformat(),
        },
    )


def write_skipped_marker(species: str):
    write_json(
        Path("cache_write_skipped.json"),
        {
            "species_id": species,
            "write_cache": False,
            "message": "Cache writing disabled by cache_config.json.",
        },
    )


def main():
    args = parse_args()
    cache_config = read_json(args.cache_config)

    if not cache_config.get("write_cache", True):
        write_skipped_marker(args.species)
        return

    incoming_refs = read_lines(args.refs)
    incoming_groups = read_lines(args.groups)
    validate_line_counts(incoming_refs, incoming_groups, args.refs, args.groups)

    (
        species_dir,
        cached_refs_file,
        cached_groups_file,
        cached_ref_groups_file,
        metadata_file,
    ) = cache_entry_paths(cache_config, args.species)
    species_dir.mkdir(parents=True, exist_ok=True)

    cached_files_exist = [
        cached_refs_file.exists(),
        cached_groups_file.exists(),
        cached_ref_groups_file.exists(),
    ]

    if all(cached_files_exist):
        print(
            f"WARNING: Complete cache entry for {args.species} already exists at "
            f"{species_dir}; leaving it unchanged.",
            file=sys.stderr,
        )
        return

    if any(cached_files_exist):
        raise SystemExit(
            f"Cannot write cache entry for {args.species}: partial entry at {species_dir} "
            f"({cached_refs_file.name} exists={cached_refs_file.exists()}, "
            f"{cached_groups_file.name} exists={cached_groups_file.exists()}, "
            f"{cached_ref_groups_file.name} exists={cached_ref_groups_file.exists()}). "
            "Cache entries are immutable; delete the directory and rerun."
        )

    shutil.copyfile(args.refs, cached_refs_file)
    shutil.copyfile(args.groups, cached_groups_file)
    shutil.copyfile(args.reference_clusters, cached_ref_groups_file)
    update_metadata(
        metadata_file,
        cache_config,
        args.species,
        [reference_id(ref) for ref in incoming_refs],
    )


if __name__ == "__main__":
    main()
