#!/usr/bin/env python3

"""
Write one generated species reference entry into the configured cache.

The script reads cache_config.json from CHECK_CACHE, checks write_cache, and
writes generated references/groups and combined reference cluster CSVs to:

  effective_cache_dir/species/<species_id>/

If references.txt and groups.txt do not already exist, they are created. If they
do exist, new reference/group pairs are appended while already-present
references are ignored as a defensive guard. references.txt and groups.txt are
kept line-aligned, so each incoming reference must have a matching group line.
<species>_reference_clusters.csv is kept in sync with the appended
reference/group pairs.

The script writes species-level metadata.json recording how many references were
added, the added reference IDs, and how many references were already present.
Top-level cache metadata is not updated here to avoid concurrent writes from
multiple species tasks.
"""

import argparse
import csv
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Write a generated species entry into the reference cache.")
    parser.add_argument("--species", required=True, help="Species or taxon identifier.")
    parser.add_argument("--refs", type=Path, required=True, help="Generated references.txt for this species.")
    parser.add_argument("--groups", type=Path, required=True, help="Generated groups.txt for this species.")
    parser.add_argument(
        "--reference-clusters",
        type=Path,
        required=True,
        help="Generated label/ref/group CSV for this species.",
    )
    parser.add_argument("--cache-config", type=Path, required=True, help="cache_config.json from CHECK_CACHE.")
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


def append_lines(path: Path, lines: list[str]):
    with open(path, "a") as out_f:
        for line in lines:
            out_f.write(f"{line}\n")


def append_reference_cluster_rows(
    cached_ref_groups_file: Path,
    incoming_ref_groups_file: Path,
    refs_to_add: list[str],
):
    refs_to_add = set(refs_to_add)
    if not refs_to_add:
        return

    with open(incoming_ref_groups_file, newline="") as in_f:
        reader = csv.DictReader(in_f)
        fieldnames = reader.fieldnames
        if fieldnames is None or "ref" not in fieldnames:
            raise SystemExit(
                f"Cannot write cache entry: {incoming_ref_groups_file} must have "
                "a header including a 'ref' column."
            )
        rows_to_add = [row for row in reader if row["ref"] in refs_to_add]

    if len(rows_to_add) != len(refs_to_add):
        raise SystemExit(
            f"Cannot write cache entry: {incoming_ref_groups_file} has "
            f"{len(rows_to_add)} rows matching {len(refs_to_add)} new references."
        )

    write_header = not cached_ref_groups_file.exists()
    with open(cached_ref_groups_file, "a", newline="") as out_f:
        writer = csv.DictWriter(out_f, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        writer.writerows(rows_to_add)


def validate_line_counts(refs: list[str], groups: list[str], refs_file: Path, groups_file: Path):
    if len(refs) != len(groups):
        raise SystemExit(
            f"Cannot write cache entry: {refs_file} has {len(refs)} lines but "
            f"{groups_file} has {len(groups)} lines."
        )


def cache_entry_paths(
    cache_config: dict, species: str
) -> tuple[Path, Path, Path, Path, Path]:
    species_dir = Path(cache_config["effective_cache_dir"]) / "species" / species
    return (
        species_dir,
        species_dir / "references.txt",
        species_dir / "groups.txt",
        species_dir / f"{species}_reference_clusters.csv",
        species_dir / "metadata.json",
    )


def existing_refs(refs_file: Path) -> set[str]:
    if not refs_file.exists():
        return set()
    return set(read_lines(refs_file))


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
    added: int,
    already_present: int,
    total: int,
    added_reference_ids: list[str],
):
    metadata = {
        "species_id": species,
        "cluster_tool": cache_config.get("cluster_tool"),
        "representatives": cache_config.get("representatives"),
        "last_update": {
            "added_references": added,
            "added_reference_ids": added_reference_ids,
            "already_present_references": already_present,
            "total_references": total,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        },
    }

    if metadata_file.exists():
        existing_metadata = read_json(metadata_file)
        updates = existing_metadata.get("updates", [])
        updates.append(metadata["last_update"])
        metadata["updates"] = updates
    else:
        metadata["updates"] = [metadata["last_update"]]

    write_json(metadata_file, metadata)


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

    if not any(cached_files_exist):
        shutil.copyfile(args.refs, cached_refs_file)
        shutil.copyfile(args.groups, cached_groups_file)
        shutil.copyfile(args.reference_clusters, cached_ref_groups_file)
        update_metadata(
            metadata_file,
            cache_config,
            args.species,
            len(incoming_refs),
            0,
            len(incoming_refs),
            [reference_id(ref) for ref in incoming_refs],
        )
        return

    if len(set(cached_files_exist)) != 1:
        raise SystemExit(
            f"Cannot update partial cache entry for {args.species}: "
            f"{cached_refs_file} exists={cached_refs_file.exists()}, "
            f"{cached_groups_file} exists={cached_groups_file.exists()}, "
            f"{cached_ref_groups_file} exists={cached_ref_groups_file.exists()}."
        )

    seen_refs = existing_refs(cached_refs_file)
    refs_to_add = []
    groups_to_add = []
    already_present = 0

    for ref, group in zip(incoming_refs, incoming_groups):
        if ref in seen_refs:
            already_present += 1
            continue
        refs_to_add.append(ref)
        groups_to_add.append(group)
        seen_refs.add(ref)

    append_lines(cached_refs_file, refs_to_add)
    append_lines(cached_groups_file, groups_to_add)
    append_reference_cluster_rows(
        cached_ref_groups_file, args.reference_clusters, refs_to_add
    )
    update_metadata(
        metadata_file,
        cache_config,
        args.species,
        len(refs_to_add),
        already_present,
        len(seen_refs),
        [reference_id(ref) for ref in refs_to_add],
    )


if __name__ == "__main__":
    main()
