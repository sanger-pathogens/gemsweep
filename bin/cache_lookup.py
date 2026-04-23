#!/usr/bin/env python3

"""
Read cache_config.json, check use_existing_cache, and look under
effective_cache_dir/species/<species_id>/ for cached species files.

Emit cache_hit.tsv if both references.txt and groups.txt exist; otherwise emit
cache_miss.tsv so the species continues through normal autoselect clustering.
"""

import argparse
import json
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Look up a Sylph species reference set in the configured cache."
    )
    parser.add_argument("--species", required=True, help="Species or taxon identifier.")
    parser.add_argument("--refs", type=Path, required=True, help="Sylph references file to use on a cache miss.")
    parser.add_argument("--cache-config", type=Path, required=True, help="cache_config.json from CHECK_CACHE.")
    return parser.parse_args()


def read_cache_config(cache_config: Path) -> dict:
    with open(cache_config) as in_f:
        return json.load(in_f)


def write_hit(species: str, cached_refs: Path, cached_groups: Path):
    with open("cache_hit.tsv", "w") as out_f:
        out_f.write("species_id\tcached_refs\tcached_groups\n")
        out_f.write(f"{species}\t{cached_refs}\t{cached_groups}\n")


def write_miss(species: str, refs: Path):
    with open("cache_miss.tsv", "w") as out_f:
        out_f.write("species_id\tsylph_refs\n")
        out_f.write(f"{species}\t{refs}\n")


def cache_entry_exists(effective_cache_dir: Path, species: str) -> tuple[bool, Path, Path]:
    species_cache_dir = effective_cache_dir / "species" / species
    cached_refs = species_cache_dir / "references.txt"
    cached_groups = species_cache_dir / "groups.txt"
    return cached_refs.is_file() and cached_groups.is_file(), cached_refs, cached_groups


def main():
    args = parse_args()
    config = read_cache_config(args.cache_config)

    if not config.get("use_existing_cache", False):
        write_miss(args.species, args.refs)
        return

    effective_cache_dir = Path(config["effective_cache_dir"])
    has_cache_entry, cached_refs, cached_groups = cache_entry_exists(effective_cache_dir, args.species)

    if has_cache_entry:
        write_hit(args.species, cached_refs, cached_groups)
    else:
        write_miss(args.species, args.refs)


if __name__ == "__main__":
    main()
