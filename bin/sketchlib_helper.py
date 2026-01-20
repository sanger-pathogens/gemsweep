#!/usr/bin/env python3

from pathlib import Path
import sys

if __name__ == '__main__':
    
    input = sys.argv[1]
    outdir = Path(sys.argv[2])

    with open(input) as f:
        file = f.read().strip().split('\n')

    with open(outdir / 'references.tsv', 'w') as out_f:
        for fasta in file:
            path = Path(fasta)
            sample = path.stem
            out_f.write(f'{sample}\t{path}\n')
