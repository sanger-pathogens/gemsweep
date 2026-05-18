#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Clean reference paths before Themisto index build."
    )
    parser.add_argument(
        "--refs_txt",
        help="Path to file containing one reference path per line.",
        type=Path,
        required=True,
    )
    parser.add_argument("--outdir", type=Path, default=".")
    return parser.parse_args()

def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

def clean_references(refs_txt: Path) -> list[str]:
    # Store the final cleaned reference paths here.
    cleaned_refs = []

    # Track paths we have already kept, so duplicate refs are skipped.
    seen_refs = set()

    for raw_line in refs_txt.read_text().splitlines():
        # Remove all whitespace anywhere in the line, including leading, trailing, and internal spaces/tabs.
        cleaned_ref = "".join(raw_line.split())

        # If this line is empty after cleaning, do not add it to cleaned_refs; go to the next line.
        if not cleaned_ref:
            continue

        # Skip duplicate paths, keeping only the first occurrence.
        if cleaned_ref in seen_refs:
            continue

        seen_refs.add(cleaned_ref)
        cleaned_refs.append(cleaned_ref)

    # Hard fail if every line was empty/invalid after cleaning.
    if not cleaned_refs:
        raise ValueError(f"No valid reference paths found in {refs_txt} after cleaning.")
    
    # Find any cleaned reference paths that do not exist on disk.
    missing_refs = [ref for ref in cleaned_refs if not Path(ref).exists()]

    # Hard fail if any cleaned reference path points to a missing file.
    if missing_refs:
        missing_list = "\n".join(missing_refs)
        raise FileNotFoundError(
            f"The following cleaned reference files do not exist:\n{missing_list}"
        )
    
    return cleaned_refs
    
def main() -> None:
    args = parse_args()
    setup_logging()

    cleaned_refs = clean_references(args.refs_txt)

    args.outdir.mkdir(parents=True, exist_ok=True)
    output = args.outdir / "references_cleaned.txt"
    output.write_text("\n".join(cleaned_refs) + "\n")

    logging.info(
        "Wrote %s cleaned reference path(s) from %s to %s",
        len(cleaned_refs),
        args.refs_txt,
        output,
    )

if __name__ == "__main__":
    main()