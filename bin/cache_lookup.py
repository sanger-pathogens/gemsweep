#!/usr/bin/env python3

"""
Read cache_config.json, check use_existing_cache, and search each directory in
read_cache_dirs (in order, so the admin-managed read-only cache takes priority
over the user cache) for species/<species_id>/ cache entries.

Emit cache_hits.tsv for the first directory in which references.txt, groups.txt
and <species>_reference_clusters.csv all exist; otherwise emit cache_miss.tsv so
the species continues through normal autoselect clustering.

Nothing is written to any cache directory by this script.
"""

import argparse
import json
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Look up a Sylph species reference set in the configured caches."
    )
    parser.add_argument("--species", required=True, help="Species or taxon identifier.")
    parser.add_argument("--refs", type=Path, required=True, help="Sylph references file to use on a cache miss.")
    parser.add_argument("--cache-config", type=Path, required=True, help="cache_config.json from CACHE_RESOLVE.")
    return parser.parse_args()


def read_cache_config(cache_config: Path) -> dict:
    with open(cache_config) as in_f:
        return json.load(in_f)


def warn(message: str):
    print(f"WARNING: {message}", file=sys.stderr)


def write_hit(species: str, cache_dir: Path, cached_refs: Path, cached_groups: Path, cached_ref_groups: Path):
    with open("cache_hits.tsv", "w") as out_f:
        out_f.write("species_id\tcached_refs\tcached_groups\tcached_ref_groups\tcache_dir\n")
        out_f.write(f"{species}\t{cached_refs}\t{cached_groups}\t{cached_ref_groups}\t{cache_dir}\n")


def write_miss(species: str, refs: Path):
    with open("cache_miss.tsv", "w") as out_f:
        out_f.write("species_id\tsylph_refs\n")
        out_f.write(f"{species}\t{refs.resolve()}\n")


def find_cache_entry(read_cache_dirs: list[str], species: str):
    """Return (cache_dir, refs, groups, ref_groups) for the first complete entry, else None."""
    for cache_dir_str in read_cache_dirs:
        cache_dir = Path(cache_dir_str)
        species_dir = cache_dir / "species" / species
        files = (
            species_dir / "references.txt",
            species_dir / "groups.txt",
            species_dir / f"{species}_reference_clusters.csv",
        )
        try:
            present = [f.is_file() for f in files]
        except OSError as exc:
            warn(f"Cannot access {species_dir}: {exc}; trying next cache.")
            continue

        if all(present):
            return (cache_dir, *files)
        if any(present):
            missing = [f.name for f, ok in zip(files, present) if not ok]
            warn(f"Incomplete cache entry for {species} in {cache_dir} (missing {', '.join(missing)}); trying next cache.")
    return None


def main():
    args = parse_args()
    config = read_cache_config(args.cache_config)

    if not config.get("use_existing_cache", False):
        write_miss(args.species, args.refs)
        return

    entry = find_cache_entry(config["read_cache_dirs"], args.species)
    if entry is None:
        write_miss(args.species, args.refs)
    else:
        write_hit(args.species, *entry)


if __name__ == "__main__":
    main()