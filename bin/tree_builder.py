#!/usr/bin/env python3
import os
import subprocess
import sys

import dendropy


def buildRapidNJ(phylip_path, meta_ID, tree_filename):
    """Use rapidNJ for more rapid tree building
    Takes a path to phylip, system calls to rapidnj executable, loads tree as
    dendropy object (cleaning quotes in node names), removes temporary files.
    """

    # construct tree
    rapidnj_cmd = [
        "rapidnj", phylip_path, "-n", "-i", "pd", "-o", "t", "-x", f"{meta_ID}.raw"
    ]

    try:
        subprocess.run(rapidnj_cmd, check=True)
        with open(meta_ID + ".raw", "r") as f, open(tree_filename, "w") as fo:
            for line in f:
                fo.write(line.replace("'", ""))
    except subprocess.CalledProcessError as e:
        sys.stderr.write("Could not run command " + rapidnj_cmd + "; returned code: " + str(e.returncode) + "\n")
        sys.exit(1)

    tree = dendropy.Tree.get(path=tree_filename, schema="newick")
    return tree


def generate_phylogeny(phylip_path, meta_ID, tree_suffix, overwrite):
    """Generate phylogeny using dendropy or RapidNJ"""

    tree_filename = f"{meta_ID}.nwk"
    if overwrite or not os.path.isfile(tree_filename):

        sys.stderr.write("Building phylogeny\n")

        tree = buildRapidNJ(phylip_path, meta_ID, tree_filename)

        tree.reroot_at_midpoint(update_bipartitions=True, suppress_unifurcations=False)

        tree.write(path=tree_filename, schema="newick", suppress_rooting=True, unquoted_underscores=True)

    else:
        sys.stderr.write("NJ phylogeny already exists; set overwrite to 'True' to replace\n")

