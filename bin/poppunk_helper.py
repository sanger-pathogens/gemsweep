#!/usr/bin/env python3
"""
Generate a references TSV file from a text file of FASTA file paths 
(one path per line) to form expected input for poppunk."


Usage:
    poppunk_helper.py <input_txt_file> <output_directory>

"""

from pathlib import Path
import sys

if __name__ == '__main__':
    
    input = sys.argv[1]
    outdir = Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)

    with open(input) as f:
        file = f.read().strip().split('\n')

    with open(outdir / 'references.tsv', 'w') as out_f:
        for fasta in file:
            path = Path(fasta)
            sample = path.stem
            out_f.write(f'{sample}\t{path}\n')
