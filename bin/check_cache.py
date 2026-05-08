#!/usr/bin/env python3

"""
Prepare the reference cache for the current clustering configuration.

This script accepts either:

1. a cache root, where it derives a configuration-specific subdirectory, or
2. an already configuration-specific cache directory.

It writes or validates metadata.json and emits cache_config.json describing
the effective cache directory for this run.

Expected layout:

<cache_root>/
  sketchlib_reps20/
    metadata.json
    species/
      escherichia_coli/
        references.txt
        groups.txt

cache_config.json contains:

{
  "use_existing_cache": true,
  "cache_root": "/path/to/cache",
  "effective_cache_dir": "/path/to/cache/specific_cache_dir",
  "cluster_tool": "sketchlib",
  "representatives": 20
}
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Prepare a configuration-specific reference cache.")
    parser.add_argument(
        "--cache-root",
        type=Path,
        required=True,
        help="User-provided cache root or configuration-specific cache directory.",
    )
    parser.add_argument("--cluster-tool", required=True, help="Clustering tool for this run.")
    parser.add_argument("--representatives", type=int, required=True, help="Representative cap for this run.")
    parser.add_argument("--out", type=Path, default=Path("cache_config.json"), help="Output cache config JSON.")
    return parser.parse_args()


def safe_path_part(value) -> str:
    value = str(value if value is not None else "")
    value = value.strip() or "none"
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_") or "none"


def build_metadata(args) -> dict:
    return {
        "cluster_tool": args.cluster_tool,
        "representatives": args.representatives,
    }


def metadata_with_note(metadata: dict, note: dict | None = None) -> dict:
    if note is None:
        return metadata
    annotated_metadata = metadata.copy()
    annotated_metadata["cache_note"] = note
    return annotated_metadata


def build_effective_cache_dir(cache_root: Path, metadata: dict) -> Path:
    cache_name = "_".join(
        [
            safe_path_part(metadata["cluster_tool"]),
            f"reps{safe_path_part(metadata['representatives'])}",
        ]
    )
    return cache_root / cache_name


def resolve_cache_paths(cache_root: Path, metadata: dict) -> tuple[Path, Path]:
    expected_cache_name = "_".join(
        [
            safe_path_part(metadata["cluster_tool"]),
            f"reps{safe_path_part(metadata['representatives'])}",
        ]
    )

    # Backward-compatible behavior: if the provided path already names the
    # configuration-specific cache directory, reuse it directly instead of
    # nesting the same suffix under itself.
    if cache_root.name == expected_cache_name:
        return cache_root.parent, cache_root

    return cache_root, build_effective_cache_dir(cache_root, metadata)


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


def config_payload(
    cache_root: Path,
    effective_cache_dir: Path,
    metadata: dict,
    use_existing_cache: bool,
    write_cache: bool,
    status: str,
    message: str | None = None,
) -> dict:
    payload = {
        "use_existing_cache": use_existing_cache,
        "write_cache": write_cache,
        "cache_root": str(cache_root),
        "effective_cache_dir": str(effective_cache_dir),
        "cluster_tool": metadata["cluster_tool"],
        "representatives": metadata["representatives"],
        "status": status,
    }
    if message:
        payload["message"] = message
    return payload


def initialise_cache_dir(effective_cache_dir: Path, metadata: dict, note: dict | None = None):
    effective_cache_dir.mkdir(parents=True, exist_ok=True)
    (effective_cache_dir / "species").mkdir(exist_ok=True)
    write_json(effective_cache_dir / "metadata.json", metadata_with_note(metadata, note))


def main():
    args = parse_args()
    requested_cache_path = args.cache_root.resolve()
    metadata = build_metadata(args)
    cache_root, effective_cache_dir = resolve_cache_paths(requested_cache_path, metadata)
    metadata_file = effective_cache_dir / "metadata.json"

    cache_root.mkdir(parents=True, exist_ok=True)
    effective_cache_dir.mkdir(parents=True, exist_ok=True)
    (effective_cache_dir / "species").mkdir(exist_ok=True)

    use_existing_cache = False
    write_cache = True
    status = "initialized"
    message = None

    if metadata_file.exists():
        try:
            existing_metadata = read_json(metadata_file)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"Invalid JSON in cache metadata {metadata_file}: {exc}") from exc

        if metadata_matches(existing_metadata, metadata):
            use_existing_cache = True
            status = "matched"
        else:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            fallback_cache_dir = effective_cache_dir.with_name(f"{effective_cache_dir.name}_{timestamp}")
            message = (
                f"Cache metadata mismatch at {metadata_file}; "
                f"existing cache will not be read or written for this run; "
                f"using new cache directory {fallback_cache_dir}. "
                "You can delete this new cache directory after the run if it is not wanted."
            )
            warn(message)
            effective_cache_dir = fallback_cache_dir
            initialise_cache_dir(
                effective_cache_dir,
                metadata,
                note={
                    "reason": "metadata_mismatch",
                    "message": message,
                    "mismatched_cache_dir": str(metadata_file.parent),
                    "mismatched_metadata": existing_metadata,
                    "created_at": timestamp,
                },
            )
            status = "fallback_initialized"
    else:
        write_json(metadata_file, metadata)

    payload = config_payload(
        cache_root=cache_root,
        effective_cache_dir=effective_cache_dir,
        metadata=metadata,
        use_existing_cache=use_existing_cache,
        write_cache=write_cache,
        status=status,
        message=message,
    )
    write_json(args.out, payload)


if __name__ == "__main__":
    main()
