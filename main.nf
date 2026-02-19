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
                               [],
    params.monochrome_logs, log)
}

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/
include { MIXED_INPUT               } from './assorted-sub-workflows/mixed_input/mixed_input.nf'
include { PREP_REFS;                
          POPPUNK;                  
          ORDER_GROUPS              } from './modules/poppunk.nf'
include { THEMISTO_BUILD_INDEX;
          THEMISTO_PSEUDOALIGN;
          THEMISTO_STATS            } from './modules/themisto.nf'
include { MSWEEP                    } from './modules/msweep.nf'
include { MGEMS                     } from './modules/mgems.nf'

//
// SUBWORKFLOWS
//

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
    params.each { key, value ->
    log.info "PARAM ${key} = ${value}" // for dev/ debugging
    }

    if (params.help) {
        printHelp()
        exit 0
    }

    validate_params()

    reads_ch = MIXED_INPUT()    // outputs channel of [meta, R1, R2] for reads_<1|2>.fastq.gz

    if (params.references) {
        // Check references exist and are not duplicated or fail early
        validate_references(params.references)

        // Set up input channels starting from references.txt
        references_ch = channel.fromPath(params.references).first()
        pp_input_ch = PREP_REFS(references_ch)
        ref_groups_ch = ORDER_GROUPS(pp_input_ch,POPPUNK(pp_input_ch).clusters).groups
        index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
        index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, references_ch).collect()
        
        // Output stats on the index (not required for anything just an additional output)
        THEMISTO_STATS(index_files_ch, index_prefix_ch)

    } else {
        // Set up input channels starting from pre-built index AND provided ref_groups
        ref_groups_ch = channel.fromPath(params.ref_groups).first()
        index_files_ch = channel.fromPath("${params.themisto_index}*").collect()
        index_prefix_ch = channel.value(file(params.themisto_index).getName())

        // Validate
        VALIDATE_PREBUILT_INPUT(index_files_ch, index_prefix_ch)

    }

    // Core Workflow
    pseudoaligned_ch = THEMISTO_PSEUDOALIGN(reads_ch,index_files_ch,index_prefix_ch)
    
    msweep_ch = MSWEEP(pseudoaligned_ch,ref_groups_ch)
    
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