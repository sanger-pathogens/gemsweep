#!/usr/bin/env python3

import sys
from pathlib import Path

if __name__ == '__main__':

    refs = sys.argv[1]
    grps = sys.argv[2]
    outdir = Path(sys.argv[3])

    with open(refs) as r:
        references = r.read().strip().split('\n')
    
    ref_dict = {}
    ref_tracker = set()
    for ref in references:
        file, path = ref.split('\t')
        file = file.replace('.', '_')
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