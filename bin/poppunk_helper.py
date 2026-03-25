#!/usr/bin/env python3
"""
Generate a references TSV file from a text file of FASTA file paths 
(one path per line) to form expected input for poppunk."


Usage:
    poppunk_helper.py --input <input_txt_file> --outdir <output_directory> --path_prefix <path_prefix>

"""

import argparse
from pathlib import Path

if __name__ == '__main__':
    
    p = argparse.ArgumentParser(description="Generate a references TSV file from a text file of FASTA file paths")
    p.add_argument("--input", help="Path to text file containing FASTA file paths", required=True, type=Path)
    p.add_argument("--outdir", help="Path to output directory", default=".", type=Path)
    p.add_argument("--path_prefix", help="Path to be prefixed to the FASTA file paths", default=None, type=Path)
    args = p.parse_args()

    args.outdir.mkdir(parents=True, exist_ok=True)

    with open(args.input) as f:
        file = f.read().strip().split('\n')

    with open(args.outdir / 'references.tsv', 'w') as out_f:
        for fasta in file:
            if args.path_prefix is None:
                path = Path(fasta)
            else:
                path = args.path_prefix / fasta
            sample = path.stem
            out_f.write(f'{sample}\t{path}\n')
