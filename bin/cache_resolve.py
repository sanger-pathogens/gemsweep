#!/usr/bin/env python3

"""
Resolve which reference caches are usable for the current clustering configuration.

Two cache locations can be supplied:

1. --ro-cache-root (optional): admin-managed, read-only. Prioritised.
2. --user-cache-root (required): user-managed, read + write. Fallback for anything 
   not found in 1.

Each may be either a cache root (a database- and configuration-specific
subdirectory is derived) or an already database- and configuration-specific
cache directory.

Behaviour:
  * The read-only cache is only used if its metadata.json exists and matches the
    requested configuration. It is never created or written to. If it is
    missing, unreadable (including permission errors) or mismatched, it is
    skipped with a warning.
  * The user cache is initialised if absent and reused if its metadata matches.
    If its metadata does not match the requested configuration, or it cannot be
    accessed or written, the script exits with an error rather than creating an
    alternative directory.
  * Downstream lookups should search `read_cache_dirs` in order (read-only cache
    first, then user cache) and write any newly clustered species to
    `write_cache_dir`.


Expected layout example (same for both caches). Caches are organised by database
so one root can hold several database releases side by side:

<cache_root>/
  gtdb_full_r226/
    ani-louvain_20_reps/
      metadata.json
      species/
        escherichia_coli/
          references.txt
          groups.txt
  gtdb_full_r232/
    ani-louvain_20_reps/
      ...

cache_config.json, which is written to `--out` (default: .), contains:

{
  "use_existing_cache": true,
  "ro_cache_dir": "/path/to/ro_cache/<db>/specific_cache_dir" | null,
  "user_cache_dir": "/path/to/user_cache/<db>/specific_cache_dir",
  "read_cache_dirs": ["<ro_cache_dir if usable>", "<user_cache_dir if matched>"],
  "write_cache_dir": "/path/to/user_cache/<db>/specific_cache_dir",
  "write_cache": true,
  "cache_root": "/path/to/user_cache",
  "cluster_method": "ani-louvain",
  "representatives": 20,
  "db": "gtdb_full_r226",
  "ro_status": "matched" | "mismatch" | "missing" | "unreadable" | "not_provided",
  "status": "initialized" | "matched"
}
"""

import argparse
import json
import re
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Resolve read-only and user reference caches for this configuration.")
    parser.add_argument("--ro-cache-root", type=Path, default=None, help="Optional admin-managed, read-only cache root or database- and configuration-specific cache directory. Checked first.")
    parser.add_argument("--user-cache-root", type=Path, required=True, help="User cache root or database- and configuration-specific cache directory with read and write access.")
    parser.add_argument("--cluster-method", required=True, help="Clustering methodology in the format <distance_type>-<algorithm>.")
    parser.add_argument("--representatives", type=int, required=True, help="Representative cap for this run.")
    parser.add_argument("--db", type=str, required=True, help="Identifier of the database from which the genomes were selected.")
    parser.add_argument("--out", type=Path, default=Path("cache_config.json"), help="Output cache config JSON.")
    return parser.parse_args()


def safe_path_part(value) -> str:
    value = str(value if value is not None else "")
    value = value.strip() or "none"
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_") or "none"


def build_metadata(args) -> dict:
    return {
        "cluster_method": args.cluster_method,
        "representatives": args.representatives,
        "db": args.db,
    }


def resolve_cache_paths(cache_root: Path, metadata: dict) -> tuple[Path, Path]:
    """Return (cache_root, effective_cache_dir) = (<root>, <root>/<db>/<method>_<N>_reps).

    Raises ValueError if the path looks like a configuration-specific cache
    directory that is not inside a directory named for the database (e.g. a
    cache laid out before databases were part of the path).
    """
    db_dir_name = safe_path_part(metadata["db"])
    expected_cache_name = "_".join(
        [
            safe_path_part(metadata["cluster_method"]),
            f"{safe_path_part(metadata['representatives'])}_reps",
        ]
    )

    # Backward-compatible behavior: if the provided path already names the
    # database- and configuration-specific cache directory, reuse it directly
    # instead of nesting the same suffix under itself.
    if cache_root.name == expected_cache_name:
        if cache_root.parent.name == db_dir_name:
            return cache_root.parent.parent, cache_root
        raise ValueError(
            f"{cache_root} looks like a configuration-specific cache directory but is not inside a "
            f"'{db_dir_name}' directory (expected <root>/{db_dir_name}/{expected_cache_name}). "
            "Caches are organised by database: move it there, or pass the cache root instead"
        )

    return cache_root, cache_root / db_dir_name / expected_cache_name


def read_json(path: Path) -> dict:
    with open(path) as in_f:
        return json.load(in_f)


def write_json(path: Path, data: dict):
    with open(path, "w") as out_f:
        json.dump(data, out_f, indent=2, sort_keys=True)
        out_f.write("\n")


def metadata_matches(existing: dict, expected: dict) -> bool:
    return all(existing.get(key) == value for key, value in expected.items())


def warn(message: str):
    print(f"WARNING: {message}", file=sys.stderr)


def check_ro_cache(ro_cache_root: Path | None, metadata: dict) -> tuple[Path | None, str]:
    """Inspect the read-only cache without ever modifying it.

    Returns (usable_cache_dir_or_None, status).
    """
    if ro_cache_root is None:
        return None, "not_provided"

    try:
        _, ro_cache_dir = resolve_cache_paths(ro_cache_root.resolve(), metadata)
    except ValueError as exc:
        warn(f"{exc}; skipping read-only cache.")
        return None, "mismatch"
    metadata_file = ro_cache_dir / "metadata.json"

    # Path.is_file() raises PermissionError (rather than returning False) on some
    # Python versions when a parent directory is not traversable by this user.
    try:
        metadata_present = metadata_file.is_file()
    except OSError as exc:
        warn(f"Cannot access read-only cache at {metadata_file}: {exc}; skipping read-only cache.")
        return None, "unreadable"

    if not metadata_present:
        warn(f"No metadata.json found in read-only cache at {metadata_file}; skipping read-only cache.")
        return None, "missing"

    try:
        existing_metadata = read_json(metadata_file)
    except (json.JSONDecodeError, OSError) as exc:
        warn(f"Could not read read-only cache metadata {metadata_file}: {exc}; skipping read-only cache.")
        return None, "unreadable"

    if not metadata_matches(existing_metadata, metadata):
        warn(
            f"Read-only cache metadata mismatch at {metadata_file} "
            f"(found {existing_metadata}, expected {metadata}); skipping read-only cache."
        )
        return None, "mismatch"

    return ro_cache_dir, "matched"


def resolve_user_cache(user_cache_root: Path, metadata: dict) -> tuple[Path, Path, bool, str]:
    """Initialise or reuse the user read/write cache.

    Exits with an error if existing metadata is invalid or does not match, or if
    the cache cannot be accessed or written.

    Returns (cache_root, effective_cache_dir, matched_existing, status).
    """
    try:
        cache_root, effective_cache_dir = resolve_cache_paths(user_cache_root.resolve(), metadata)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    metadata_file = effective_cache_dir / "metadata.json"

    try:
        cache_root.mkdir(parents=True, exist_ok=True)
        effective_cache_dir.mkdir(parents=True, exist_ok=True)
        (effective_cache_dir / "species").mkdir(exist_ok=True)

        if not metadata_file.exists():
            write_json(metadata_file, metadata)
            return cache_root, effective_cache_dir, False, "initialized"

        existing_metadata = read_json(metadata_file)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in cache metadata {metadata_file}: {exc}") from exc
    except OSError as exc:
        raise SystemExit(
            f"Cannot access or write the user cache at {effective_cache_dir}: {exc}. "
            "--user-cache-root must be a location you have read and write access to."
        ) from exc

    if not metadata_matches(existing_metadata, metadata):
        raise SystemExit(
            f"User cache metadata mismatch at {metadata_file} "
            f"(found {existing_metadata}, expected {metadata}). "
            "Use a different --user-cache-root, or delete/update this cache if it is stale."
        )

    return cache_root, effective_cache_dir, True, "matched"


def main():
    args = parse_args()
    metadata = build_metadata(args)

    # Read-only (admin) cache: checked first, never modified.
    ro_cache_dir, ro_status = check_ro_cache(args.ro_cache_root, metadata)

    # User cache: read + write.
    user_cache_root, user_cache_dir, user_matched, status = resolve_user_cache(
        args.user_cache_root, metadata
    )

    if ro_cache_dir is not None and ro_cache_dir.resolve() == user_cache_dir.resolve():
        raise SystemExit(
            f"--ro-cache-root and --user-cache-root resolve to the same cache directory ({user_cache_dir}). "
            "The read-only cache must be separate from the user cache."
        )

    # admin-managed read-only cache takes priority over the user's cache, so comes first
    read_cache_dirs = []
    if ro_cache_dir is not None:
        read_cache_dirs.append(str(ro_cache_dir))
    if user_matched:
        read_cache_dirs.append(str(user_cache_dir))

    payload = {
        "use_existing_cache": bool(read_cache_dirs),
        "ro_cache_dir": str(ro_cache_dir) if ro_cache_dir is not None else None,
        "user_cache_dir": str(user_cache_dir),
        "read_cache_dirs": read_cache_dirs,
        "write_cache_dir": str(user_cache_dir),
        "write_cache": True,
        "cache_root": str(user_cache_root),
        "cluster_method": metadata["cluster_method"],
        "representatives": metadata["representatives"],
        "db": metadata["db"],
        "ro_status": ro_status,
        "status": status,
    }
    write_json(args.out, payload)


if __name__ == "__main__":
    main()