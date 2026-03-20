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
                               [${workflow.ProjectDir}/assorted-sub-workflows/sylph_refset/schema.json],
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
include { PUBLISH_GROUPS;
          PUBLISH_REPS          } from './modules/publish_intermediates.nf'
include { THEMISTO_BUILD_INDEX; 
          THEMISTO_PSEUDOALIGN;
          THEMISTO_STATS        } from './modules/themisto.nf'
include { MSWEEP                } from './modules/msweep.nf'
include { MGEMS                 } from './modules/mgems.nf'

//
// SUBWORKFLOWS
//
include { REFINE_REFS } from './subworkflows/derep_groups.nf'

include { VALIDATE_PREBUILT_INPUT } from './subworkflows/validate_prebuilt_input.nf'

/*
Helper Scripts
*/

include { validate_params;
          validate_references } from './modules/validate.nf'

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

    reads_ch = MIXED_INPUT()    // outputs channel of [meta, R1, R2] for reads_<1|2>.fastq.gz

    if (params.ref_mode == "index") {
        // Set up input channels starting from pre-built index AND provided ref_groups
        ref_groups_ch = channel.fromPath(params.ref_groups).first()
        index_files_ch = channel.fromPath("${params.themisto_index}*{tdbg,tcolors}").collect()
        index_prefix_ch = channel.value(file(params.themisto_index).getName())

        // Validate
        VALIDATE_PREBUILT_INPUT(index_files_ch, index_prefix_ch)
    } else if (params.ref_mode == "no_derep") {
        // Set up input channels starting from references.txt
        references_ch = channel.fromPath(params.references).first()

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)
        poppunk_clusters_csv = POPPUNK.out.clusters

        representatives_ch = references_ch // no dereplication
        ref_groups_ch = ORDER_GROUPS(PREP_REFS.out.refs_csv, poppunk_clusters_csv).groups
        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if (params.ref_mode == "single_species_derep") {
        // Set up input channels starting from references.txt
        references_ch = channel.fromPath(params.references).first()

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)
        poppunk_clusters_csv = POPPUNK.out.clusters

        REFINE_REFS(
            references_ch,
            poppunk_clusters_csv,
            POPPUNK.out.dist_matrix
        )

        representatives_ch = REFINE_REFS.out.representatives_ch
        ref_groups_ch = REFINE_REFS.out.ref_groups_ch

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else if (params.ref_mode == "multispecies_derep") {
        // To populate
        log.error("Input option 'multispecies_derep' not implemented yet! Watch this space :)")

    } else if (params.ref_mode == "sylph_autoselect") {
        // Generate candidate references from reads via Sylph.
        SYLPH_REF_SELECTION(reads_ch)
        references_ch = SYLPH_REF_SELECTION.out.references

        //TODO Need to group refs per species (or other taxon here) here for use with poppunk

        // Cluster references
        PREP_REFS(references_ch)
        POPPUNK(PREP_REFS.out.refs_csv)
        poppunk_clusters_csv = POPPUNK.out.clusters

        if (params.refine_refs) {
            REFINE_REFS(
                references_ch,
                poppunk_clusters_csv,
                POPPUNK.out.dist_matrix
            )
            representatives_ch = REFINE_REFS.out.representatives_ch
            ref_groups_ch = REFINE_REFS.out.ref_groups_ch

        } else {
            representatives_ch = references_ch
            ref_groups_ch = ORDER_GROUPS(PREP_REFS.out.refs_csv, poppunk_clusters_csv).groups
        }

        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, representatives_ch).collect()

    } else {
        log.error("Unrecognized input mode '${params.ref_mode}'.")
    }

    if (!params.ref_mode == "index") {
        // Output stats on the index (not required for anything just an additional output)
        THEMISTO_STATS(index_files_ch, index_prefix_ch)
    }

    // Core Workflow
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
