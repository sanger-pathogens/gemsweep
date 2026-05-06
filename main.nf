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
include { CHECK_CACHE;
          CACHE_LOOKUP;
          WRITE_CACHE_ENTRY     } from './modules/cache.nf'
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
        candidate_references_ch = SYLPH_REF_SELECTION.out.references

        // call cache search process if cache_dir is provided, otherwise skip to clustering with Sylph outputs as input.
        // if cache s enabled, split sylph candidate into cached and uncached.
        if (params.cache_dir) {
            // Cache-enabled path: seed ref/group channels with cache hits and cluster cache misses.
            CHECK_CACHE()
            cache_config_ch = CHECK_CACHE.out.config.first()
            CACHE_LOOKUP(candidate_references_ch, cache_config_ch)

            CACHE_LOOKUP.out.hits
            | splitCsv(header: true, sep: '\t')
            | map { row ->
                tuple([ID: row.species_id], file(row.cached_refs))
            }
            | set { rep_refs_ch }

            ref_groups_ch = CACHE_LOOKUP.out.hits
                | splitCsv(header: true, sep: '\t')
                | map { row ->
                    tuple([ID: row.species_id], file(row.cached_groups))
                }

            // From this point, candidate_references_ch means:
            // "candidate references that were NOT found in cache and still need clustering".
            candidate_references_ch = CACHE_LOOKUP.out.misses
                | map { meta, cache_miss_tsv, sylph_refs ->
                    tuple(meta, sylph_refs)
                }
        } else {
            // Cache-disabled path: all Sylph refs continue to clustering.
            rep_refs_ch = Channel.empty()
            ref_groups_ch = Channel.empty()
        }

        // Cluster references
        // only uncached candidate references go through PREP_REFS and clustering
        PREP_REFS(candidate_references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)

        // Always refine autoselected candidate references before indexing.
        candidate_references_ch
        | join(POPPUNK.out.clusters)
        | join(POPPUNK.out.dist_matrix)
        | set { refine_refs_input }

        REFINE_REFS(refine_refs_input)

        generated_rep_refs_ch = REFINE_REFS.out.representatives_ch
        generated_ref_groups_ch = REFINE_REFS.out.ref_groups_ch

        // store newly generated species cache entries for future runs.
        if (params.cache_dir) {
            generated_rep_refs_ch
            | join(generated_ref_groups_ch)
            | set { generated_cache_entries_ch}
            
            WRITE_CACHE_ENTRY(generated_cache_entries_ch, cache_config_ch)
        }

        // Build the current-run reference set from cached + generated.
        representatives_ch = rep_refs_ch.mix(generated_rep_refs_ch)
        ref_groups_ch = ref_groups_ch.mix(generated_ref_groups_ch)


        representatives_ch
        | join(ref_groups_ch)
        | multiMap { meta, refs, groups ->
            refs: refs
            groups: groups
        }
        | set { ref_groups }

        ref_groups.refs
        | map { refs_file -> refs_file.path }
        | collectFile(name: "refs.txt", newLine: true)
        | set { refs }

        ref_groups.groups
        | map { groups_file -> groups_file.path }
        | collectFile(name: "groups.txt", newLine: true)
        | set { groups }

        COMBINE_REFS(refs, groups)

        // Build themisto index
        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, COMBINE_REFS.out.references).collect()
    }

    if (params.ref_mode != "index") {
        // Output stats on the index (not required for anything just an additional output)
        THEMISTO_STATS(index_files_ch, index_prefix_ch)
    }


    // Core Workflow
    pseudoaligned_ch = THEMISTO_PSEUDOALIGN(reads_ch, index_files_ch, index_prefix_ch)
    // Normalise ref_groups_ch so downstream processes always receive group.txt files instead of mixed tuple/file entries.
    ref_groups_ch = ref_groups_ch.map { meta, groups_file ->
    return groups_file ? groups_file : meta
    }

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
