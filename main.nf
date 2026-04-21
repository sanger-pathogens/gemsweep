#!/usr/bin/env nextflow
// Copyright (C) 2024 Genome Research Ltd.

/*
========================================================================================
    HELP
========================================================================================
*/

def logo = NextflowTool.logo(workflow, params.monochrome_logs)

log.info logo

NextflowTool.commandLineParams(workflow.commandLine, log, params.monochrome_logs)


def printHelp() {
    NextflowTool.help_message("${workflow.ProjectDir}/schema.json", 
                               ["${workflow.ProjectDir}/assorted-sub-workflows/sylph_refset/schema.json"],
    params.monochrome_logs, log)
}

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/
include { MIXED_INPUT           } from './assorted-sub-workflows/mixed_input/mixed_input.nf'
include { SYLPH_REF_SELECTION   } from './assorted-sub-workflows/sylph_refset/sylph_refset.nf'
include { PREP_REFS;             
          POPPUNK;                
          ORDER_GROUPS          } from './modules/poppunk.nf'
include { THEMISTO_BUILD_INDEX; 
          THEMISTO_PSEUDOALIGN;
          THEMISTO_STATS        } from './modules/themisto.nf'
include { MSWEEP                } from './modules/msweep.nf'
include { MGEMS                 } from './modules/mgems.nf'
include { COMBINE_REFS          } from './modules/helper_processes.nf'

//
// SUBWORKFLOWS
//
include { REFINE_REFS } from './subworkflows/refine_refs.nf'

include { VALIDATE_PREBUILT_INPUT } from './subworkflows/validate_prebuilt_input.nf'

/*
Helper Scripts
*/

include { validate_params } from './modules/validate.nf'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    // params.each { key, value ->
    // log.info "PARAM ${key} = ${value}" // for dev/ debugging
    // }

    if (params.help) {
        printHelp()
        exit 0
    }

    validate_params()

    if (!params.skip_main) {
        reads_ch = MIXED_INPUT()    // outputs channel of [meta, R1, R2] for reads_<1|2>.fastq.gz
    }

    if (params.ref_mode == "index") {
        // Set up input channels starting from pre-built index AND provided ref_groups
        ref_groups_ch = channel.fromPath(params.ref_groups).first() // using .first() to get a value channel
        index_files_ch = channel.fromPath("${params.themisto_index}*{tdbg,tcolors}").collect()
        index_prefix_ch = channel.value(file(params.themisto_index).getName())

        // Validate
        VALIDATE_PREBUILT_INPUT(index_files_ch, index_prefix_ch)

    } else if ((params.ref_mode == "full") && (params.cluster_tool == "poppunk")) {
        // Set up input channels starting from references.txt
        channel.fromPath(params.references)
        | first() // using .first() to get a value channel
        | map { ref -> [ ["ID": "all_refs"], ref ] }
        | set { references_ch }

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)

        PREP_REFS.out.refs_csv
        | join(POPPUNK.out.clusters)
        | ORDER_GROUPS

        representatives_ch = references_ch // no dereplication
        ref_groups_ch = ORDER_GROUPS.out.groups

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if ((params.ref_mode == "full") && (params.cluster_tool == "sketchlib")) {
        // To populate
        error("Sketchlib reference clustering not implemented yet! Watch this space :)")

    } else if ((params.ref_mode == "refine") && (params.cluster_tool == "poppunk")) {
        // Set up input channels starting from references.txt
        channel.fromPath(params.references)
        | first() // using .first() to get a value channel
        | map { ref -> [ ["ID": "all_refs"], ref ] }
        | set { references_ch }

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)

        // Select representatives from clusters
        references_ch
        | join(POPPUNK.out.clusters)
        | join(POPPUNK.out.dist_matrix)
        | set { refine_refs_input }

        REFINE_REFS(refine_refs_input)

        // Split into references and groups, then publish
        REFINE_REFS.out.rep_refs_and_groups
        | map { meta, ref_groups_file -> ref_groups_file}
        | collect
        | COMBINE_REFS

        representatives_ch = COMBINE_REFS.out.references.first()
        ref_groups_ch = COMBINE_REFS.out.groups.first()

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if ((params.ref_mode == "refine") && (params.cluster_tool == "sketchlib")) {
        // To populate
        error("Sketchlib reference refinement not implemented yet! Watch this space :)")

    } else if (params.ref_mode == "autoselect") {

        // Generate candidate references from reads via Sylph.
        SYLPH_REF_SELECTION(reads_ch)

// For each detected species/taxon (meta.ID), check whether cached
// references.txt and groups.txt already exist under params.species_ref_cache.
//
// If cached:
// - reuse the stored species-level files
//
// If uncached:
// - run the normal downstream species-prep path
// - write the new species references.txt and groups.txt into the cache
//
// After that:
// - combine cached + newly generated species references into one final references.txt
// - combine cached + newly generated species groups into one final groups.txt
// - use those combined files for Themisto index building
//
// Cache layout (current proposal):
// species_ref_cache/
// ├── escherichia_coli/
// │   ├── references.txt
// │   └── groups.txt
// ├── klebsiella_pneumoniae/
// │   ├── references.txt
// │   └── groups.txt
// └── staphylococcus_aureus/
//     ├── references.txt
//     └── groups.txt
//
// Optional future extension:
// - add per-species metadata and/or version history if provenance/versioning is needed

        if (params.species_ref_cache) {
            // cache lookup logic here
            sylph_references_ch = SYLPH_REF_SELECTION.out.references

            sylph_references_ch
            | map {meta, refs ->
                def species_dir = file("${params.species_ref_cache}/${meta.ID}")
                def cached_refs = file("${species_dir}/references.txt")
                def cached_groups = file("${species_dir}/groups.txt")
                tuple(meta, refs, cached_refs, cached_groups)
            }
            // split species reference genomes into cached vs uncached paths for downstream processing 
            | branch {
                cached: it[2].exists() && it[3].exists()
                uncached: !(it[2].exists() && it[3].exists())
            }
            | set {cache_status}

            // each branch gets its own downstream handling
            cache_status.cached
            | map { meta, refs, cached_refs, cached_groups ->
                [meta, cached_refs]
            }
            | set { cached_references_ch }

            cache_status.cached
            | map { meta, refs, cached_refs, cached_groups ->
                [meta, cached_groups]
            }
            | set { cached_groups_ch }
        
            cache_status.uncached
            | map { meta, refs, cached_refs, cached_groups ->
                [meta, refs]
            }
            | set { uncached_references_ch }

        } else {
            references_ch = SYLPH_REF_SELECTION.out.references
        }
        

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)
        poppunk_clusters_csv = POPPUNK.out.clusters

        // Dereplicate/Refine references per cluster
        references_ch
        | join(POPPUNK.out.clusters)
        | join(POPPUNK.out.dist_matrix)
        | set { refine_refs_input }

        REFINE_REFS(refine_refs_input)

        // Split into references and groups, then combine across all taxa
        REFINE_REFS.out.rep_refs_and_groups
        | map { meta, ref_groups_file -> ref_groups_file}
        | collect
        | COMBINE_REFS

        representatives_ch = COMBINE_REFS.out.references.first()
        ref_groups_ch = COMBINE_REFS.out.groups.first()

        // Build themisto index
        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()
    }

    if (params.ref_mode !== "index") {
        // Output stats on the index (not required for anything just an additional output)
        THEMISTO_STATS(index_files_ch, index_prefix_ch)
    }

    // Core Workflow
    if (!params.skip_main) {
        pseudoaligned_ch = THEMISTO_PSEUDOALIGN(reads_ch, index_files_ch, index_prefix_ch)
        
        msweep_ch = MSWEEP(pseudoaligned_ch, ref_groups_ch)
        
        MGEMS(
            reads_ch
                .join(pseudoaligned_ch, by: 0)
                .join(msweep_ch, by: 0)
                .map { meta, r1, r2, aln1, aln2, abund, probs ->
                    tuple(meta, r1, r2, aln1, aln2, abund, probs)
                },
                index_files_ch,
                index_prefix_ch,
                ref_groups_ch
        )
    }
}
