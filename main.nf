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
include { SKETCHLIB_SKETCH;
          SKETCHLIB_CLUSTER     }  from './modules/sketchlib.nf'

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

    if (!params.ref_prep_only || ref_mode == 'autoselect') { // only autoselect requires reads for ref prep
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
        POPPUNK(PREP_REFS.out.refs_tsv)

        PREP_REFS.out.refs_tsv
        | join(POPPUNK.out.clusters)
        | ORDER_GROUPS

        representatives_ch = references_ch // no dereplication
        ref_groups_ch = ORDER_GROUPS.out.groups.map { meta, groups_file -> groups_file }

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if ((params.ref_mode == "full") && (params.cluster_tool == "sketchlib")) {
        // Set up input channels starting from references.txt
        channel.fromPath(params.references)
        | first() // using .first() to get a value channel
        | map { ref -> [ ["ID": "all_refs"], ref ] }
        | set { references_ch }

        // Cluster references
        PREP_REFS(references_ch)

        SKETCHLIB_SKETCH(PREP_REFS.out.refs_tsv)
        | SKETCHLIB_CLUSTER

        PREP_REFS.out.refs_tsv
        | join(SKETCHLIB_CLUSTER.out.clusters)
        | ORDER_GROUPS

        // no dereplication
        references_ch
        | map { meta, refs ->
            refs
        }
        | set {representatives_ch}

        ref_groups_ch = ORDER_GROUPS.out.groups

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if ((params.ref_mode == "refine") && (params.cluster_tool == "poppunk")) {
        // Set up input channels starting from references.txt
        channel.fromPath(params.references)
        | first() // using .first() to get a value channel
        | map { ref -> [ ["ID": "all_refs"], ref ] }
        | set { references_ch }

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_tsv)

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

        representatives_ch = COMBINE_REFS.out.references
        ref_groups_ch = COMBINE_REFS.out.groups

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if ((params.ref_mode == "refine") && (params.cluster_tool == "sketchlib")) {
        // Set up input channels starting from references.txt
        channel.fromPath(params.references)
        | first() // using .first() to get a value channel
        | map { ref -> [ ["ID": "all_refs"], ref ] }
        | set { references_ch }

        // Cluster references
        PREP_REFS(references_ch)
        SKETCHLIB_SKETCH(PREP_REFS.out.refs_tsv)
        | SKETCHLIB_CLUSTER

        // Select representatives from clusters
        references_ch
        | join(SKETCHLIB_CLUSTER.out.clusters)
        | join(SKETCHLIB_CLUSTER.out.dist_matrix)
        | set { refine_refs_input }

        REFINE_REFS(refine_refs_input)

        // Split into references and groups, then publish
        REFINE_REFS.out.rep_refs_and_groups
        | map { meta, ref_groups_file -> ref_groups_file}
        | collect
        | COMBINE_REFS

        representatives_ch = COMBINE_REFS.out.references
        ref_groups_ch = COMBINE_REFS.out.groups

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if (params.ref_mode == "autoselect") {

        // Generate candidate references from reads via Sylph.
        SYLPH_REF_SELECTION(reads_ch)
        candidate_references_ch = SYLPH_REF_SELECTION.out.references

        // call cache search process if cache_dir is provided, otherwise skip to clustering with Sylph outputs as input.
        // if cache is enabled, split sylph candidate into cached and uncached.
        if (params.cache_dir) {
            // Cache-enabled path: create cached ref/group pairs and cluster cache misses.
            CHECK_CACHE()
            cache_config_ch = CHECK_CACHE.out.config.first()
            CACHE_LOOKUP(candidate_references_ch, cache_config_ch)

            // Cached combined label/ref/group files for the current run combine step.
            cached_ref_group_files_ch = CACHE_LOOKUP.out.hits
                .map { meta, cache_hits_tsv, refs_file -> cache_hits_tsv }
                .splitCsv(header: true, sep: '\t')
                .map { row ->
                    tuple([ID: row.species_id], file(row.cached_ref_groups))
                }

            // Candidate references not found in the cache; these still need clustering/refinement.
            candidate_refs_to_cluster_ch = CACHE_LOOKUP.out.misses
                | map { meta, cache_miss_tsv, sylph_refs ->
                    tuple(meta, sylph_refs)
                }
        } else {
            // Cache-disabled path: all Sylph refs continue to clustering.
            cached_ref_group_files_ch = Channel.empty()
            // With no cache, every Sylph candidate reference set must be clustered/refined.
            candidate_refs_to_cluster_ch = candidate_references_ch
        }

        // Cluster references
        // only uncached candidate references go through PREP_REFS and clustering
        PREP_REFS(candidate_refs_to_cluster_ch)
        POPPUNK(PREP_REFS.out.refs_tsv)
        poppunk_clusters_csv = POPPUNK.out.clusters

        // Always refine autoselected candidate references before indexing.
        candidate_refs_to_cluster_ch
        | join(POPPUNK.out.clusters)
        | join(POPPUNK.out.dist_matrix)
        | set { refine_refs_input }

        REFINE_REFS(refine_refs_input)

        // For current run combine_refs.py input: tuple(meta, label_ref_group_csv)
        generated_ref_group_files_ch = REFINE_REFS.out.rep_refs_and_groups

        // all refine_refs emit outputs carry same meta so i can just join these two
        generated_rep_refs_ch = REFINE_REFS.out.representatives_ch
        generated_ref_groups_ch = REFINE_REFS.out.ref_groups_ch

        // tuple(meta, references_txt, clusters_txt)
        generated_ref_group_pairs_ch = generated_rep_refs_ch
            .join(generated_ref_groups_ch)

        // store newly generated species cache entries for future runs.
        if (params.cache_dir) {
            generated_ref_group_pairs_ch
                .join(generated_ref_group_files_ch)
                .set { generated_cache_entries_ch}
            
            WRITE_CACHE_ENTRY(generated_cache_entries_ch, cache_config_ch)
        }

        // Mix cached and generated combined ref/group CSVs for the current run.
        combined_ref_group_files_ch = cached_ref_group_files_ch.mix(generated_ref_group_files_ch)

        // Sort species for reproducible ref/group file order across runs.
        combined_ref_group_files_ch
            .collect(flat: false)
            .flatMap { entries ->
                entries.sort { a, b -> a[0].ID <=> b[0].ID }
            }
            .map { meta, ref_group_file -> ref_group_file }
            .collect()
            .set { ref_group_files }

        COMBINE_REFS(ref_group_files)
        ref_groups_ch = COMBINE_REFS.out.groups

        // Build themisto index
        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, COMBINE_REFS.out.references).collect()
    }

    if (params.ref_mode != "index") {
        // Output stats on the index (not required for anything just an additional output)
        THEMISTO_STATS(index_files_ch, index_prefix_ch)
    }

    // Core Workflow
    if (!params.ref_prep_only) {
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
