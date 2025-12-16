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
include { MIXED_INPUT          } from './assorted-sub-workflows/mixed_input/mixed_input.nf'
include { THEMISTO_PSEUDOALIGN } from './modules/themisto.nf'
include { MSWEEP               } from './modules/msweep.nf'
include { MGEMS                } from './modules/mgems.nf'

//
// SUBWORKFLOWS
//

/*
Helper Scripts
*/

//include { validate_parameters } from './modules/validate.nf'



/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    if (params.help) {
        printHelp()
        exit 0
    }

    //validate_parameters()

    //reads_ch = MIXED_INPUT()    // outputs channel of [meta, R1, R2] for reads_<1|2>.fastq.gz
    reads_ch = channel
        .fromPath(params.manifest)
        .splitCsv(header:true)
        .map { row ->
            // row is a map: [ID: 'sample1', R1: 'reads/sample1_R1.fastq.gz', R2: 'reads/sample1_R2.fastq.gz']
            def meta = [id: row.ID]
            tuple(meta, file(row.R1), file(row.R2))
        }

    ref_groups_ch = params.ref_groups ? channel.fromPath(params.ref_groups) :    // If user supplies groups, give those
                 (params.skip_clustering ? channel.empty() : channel.empty())    // If user skips clustering give empty channel, else give poppunk clusters (not yet built)
    
    index_ch = channel.value(params.themisto_index)
    
    pseudoaligned_ch = THEMISTO_PSEUDOALIGN(reads_ch,index_ch)
    
    msweep_ch = MSWEEP(pseudoaligned_ch,ref_groups_ch)
    
    MGEMS(
        pseudoaligned_ch
            .join(msweep_ch, by: 0)
            .map { themisto_tuple, msweep_tuple -> themisto_tuple + msweep_tuple[1..2] }
            .combine(index_ch, channel.value(params.ref_groups))
            .map { tuple, index, ref_groups -> tuple + [index, ref_groups] }
    )



}