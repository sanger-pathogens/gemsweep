#!/usr/bin/env python3

"""
This script takes clustering output and reorders the cluster
assignments so they align positionally with the supplied reference list.

References TSV includes an ID and path to reference genome.
Groups CSV includes the ID and it's group ID e.g. PopPUNK/sketchlib cluster.

Usage:
    order_groups.py <references.tsv> <poppunk_groups.csv> <output_directory>
"""

from pathlib import Path
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description="Reorder groups file to positionally match the references file",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--outdir", 
        type=Path, 
        required=True, 
        help="Output directory"
    )
    parser.add_argument(
        "--groups_csv", 
        type=Path, 
        required=True, 
        help="CSV containing genome ID followed by group assignment"
    )
    parser.add_argument(
        "--references_tsv",
        type=Path,
        required=True,
        help="TSV containing genome ID followed by path to the fasta"
    )
    parser.add_argument(
        "--cluster_tool",
        type=str,
        required=False,
        help="Indicates which format the groups file will be in: poppunk|sketchlib"
    )
    return parser.parse_args()

def main():
    args = parse_args()

    refs = args.references_tsv
    grps = args.groups_csv
    outdir = args.outdir

    args=parse_args()

    with open(refs) as r:
        references = r.read().strip().split('\n')
    
    ref_dict = {}
    ref_tracker = set()
    for ref in references:
        file, path = ref.split('\t')
        if args.cluster_tool == "poppunk":
            file = file.replace('.', '_')    # match poppunks ID editing
        ref_dict[file] = 'missing'
        ref_tracker.add(file)
    
    with open(grps) as g:
        groups = g.read().strip().split('\n')[1:]
    
    for grp in groups:
        id, cluster = grp.split(',')
        if id not in ref_tracker:
            print(f'missing {id}')
            continue
        ref_dict[id] = cluster
    
    with open(outdir / 'groups.txt', 'w') as out_f:
        for id, group in ref_dict.items():
            out_f.write(f'{group}\n')
        
    return

if __name__ == '__main__':
    main()