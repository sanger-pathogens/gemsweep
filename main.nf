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
include { REFINE_REFS             } from './subworkflows/refine_refs.nf'
include { VALIDATE_PREBUILT_INPUT } from './subworkflows/validate_prebuilt_input.nf'
include { CLUSTER_REFS            } from './subworkflows/cluster.nf'

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

    // Set up reads channel if required
    if (!params.ref_prep_only || params.ref_mode == 'autoselect') { // only autoselect requires reads for ref prep
        reads_ch = MIXED_INPUT()    // outputs channel of [meta, R1, R2] for reads_<1|2>.fastq.gz
    }

    // Set up reference channels (themisto index and reference groups) according to ref_mode
    if (params.ref_mode == "index") {
        // Set up input channels starting from pre-built index AND provided ref_groups
        ref_groups_ch = channel.value(file(params.ref_groups))
        index_ch = channel.fromPath("${params.themisto_index}*{tdbg,tcolors}")
          .collect()
          .map { files -> tuple(file(params.themisto_index).getName(), files) }

        // Validate
        VALIDATE_PREBUILT_INPUT(index_ch)

    } else if (params.ref_mode == "autoselect") {
        // Generate candidate references by profiling reads
        SYLPH_REF_SELECTION(reads_ch)
        sylph_refs_ch = SYLPH_REF_SELECTION.out.references

        // If cache dir provided check for relevant cached species references
        if (params.cache_dir) {
            CHECK_CACHE()
            cache_config_ch = CHECK_CACHE.out.config.first() // TODO: check - is check_cache generating this config or reading it?
            CACHE_LOOKUP(sylph_refs_ch, cache_config_ch) // TODO: change very similar process names

            // Organise cached references
            CACHE_LOOKUP.out.hits
            | map { meta, cache_hits_tsv, refs_file -> cache_hits_tsv }
            | splitCsv(header: true, sep: '\t')
            | map { row -> tuple([ID: row.species_id], file(row.cached_ref_groups)) }
            | set { cached_ref_group_files_ch }

            // Organise (uncached) candidate references requiring clustering and refinement
            CACHE_LOOKUP.out.misses
            | map { meta, cache_miss_tsv, sylph_refs -> tuple(meta, sylph_refs) }
            | set { candidate_refs_ch }

        } else {
            // Without a set cache dir all continue as candidate references to clustering and refinement
            cached_ref_group_files_ch = channel.empty()
            candidate_refs_ch = sylph_refs_ch
        }

        // Cluster candidate references
        PREP_REFS(candidate_refs_ch)
        | CLUSTER_REFS

        // Always refine autoselected candidate references before indexing
        candidate_refs_ch
        | join(CLUSTER_REFS.out.clusters)
        | join(CLUSTER_REFS.out.dist_matrix)
        | REFINE_REFS

        generated_rep_refs_ch = REFINE_REFS.out.representatives_ch
        generated_ref_groups_ch = REFINE_REFS.out.ref_groups_ch

        // Store newly generated species cache entries in dir, if provided
        if (params.cache_dir) {
            generated_rep_refs_ch
            | join(generated_ref_groups_ch)
            | join(REFINE_REFS.out.rep_refs_and_groups)
            | set { generated_cache_entries_ch }
            
            WRITE_CACHE_ENTRY(generated_cache_entries_ch, cache_config_ch)
        }

        // Mix cached and generated species refs
        cached_ref_group_files_ch
        | mix(REFINE_REFS.out.rep_refs_and_groups)
        | set { combined_ref_group_files_ch }

        // Sort species for reproducible ref/group file order across runs
        combined_ref_group_files_ch
        | collect(flat: false)
        | map { entries ->
            entries.sort { a, b -> a[0].ID <=> b[0].ID }
                   .collect { meta, ref_group_file -> ref_group_file } }
        | COMBINE_REFS

        COMBINE_REFS.out.groups
        | set { ref_groups_ch }

        // Build themisto index
        index_ch = THEMISTO_BUILD_INDEX(COMBINE_REFS.out.references).first()

    } else if (params.ref_mode in ["refine", "full"]) {
        // Set up input channels starting from references.txt
        channel.value(file(params.references))
        | map { ref -> [ ["ID": "all_refs"], ref ] }
        | set { references_ch }

        // Cluster references
        PREP_REFS(references_ch)
        | CLUSTER_REFS

        if (params.ref_mode == "refine") {
            references_ch
            | join(CLUSTER_REFS.out.clusters)
            | join(CLUSTER_REFS.out.dist_matrix)
            | REFINE_REFS

            // Split into references and groups, then publish
            REFINE_REFS.out.rep_refs_and_groups
            | map { meta, ref_groups_file -> ref_groups_file}
            | collect
            | COMBINE_REFS

            COMBINE_REFS.out.groups
            | set { ref_groups_ch }

            representatives_ch = COMBINE_REFS.out.references
        } else if (params.ref_mode == "full") {
            PREP_REFS.out.refs_tsv
            | join(CLUSTER_REFS.out.clusters)
            | ORDER_GROUPS

            // no dereplication
            references_ch
            | map { meta, refs -> refs }
            | set { representatives_ch }

            ORDER_GROUPS.out.groups
            | map { meta, groups_file -> groups_file }
            | set { ref_groups_ch }
        }

        // Build themisto index
        index_ch = THEMISTO_BUILD_INDEX(representatives_ch).first()

    }

    if (params.ref_mode != "index") {
        // Output stats on the index (not required for anything just an additional output)
        THEMISTO_STATS(index_ch)
    }

    // Run abundance est. and binning workflow
    if (!params.ref_prep_only) {
        pseudoaligned_ch = THEMISTO_PSEUDOALIGN(reads_ch, index_ch)
        msweep_ch = MSWEEP(pseudoaligned_ch, ref_groups_ch)
        
        MGEMS(
            reads_ch
              .join(pseudoaligned_ch, by: 0)
              .join(msweep_ch, by: 0)
              .map { meta, r1, r2, aln1, aln2, abund, probs ->
                  tuple(meta, r1, r2, aln1, aln2, abund, probs)
              },
            index_ch,
            ref_groups_ch
        )
    } else { // Should be caught in validate.nf but here as a failsafe
        error("Unrecognised ref_mode: '${params.ref_mode}'.")
    }
}
