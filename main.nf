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
include { DEREP_GROUPS } from './subworkflows/derep_groups.nf'

/*
Helper Scripts
*/

include { validate_params;
          validate_index;
          validate_ref_groups } from './modules/validate.nf'

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

   // reads_ch = MIXED_INPUT()    // outputs channel of [meta, R1, R2] for reads_<1|2>.fastq.gz



   //if (params.references) {
        // Set up input channels starting from references.txt
        //references_ch = channel.fromPath("/data/pam/team230/tm22/scratch/tickets/PAT-3113/references.txt").first()
        //pp_input_ch = PREP_REFS(references_ch)

        //poppunk_ch = POPPUNK(PREP_REFS(references_ch))
        poppunk_dists_ch = channel.fromPath("/data/pam/team230/cc52/scratch/dev_tests/msweep-mgems/python_derep/218_ref_pp_database.dists.npy")
        poppunk_clusters_csv = channel.fromPath("/data/pam/team230/cc52/scratch/dev_tests/msweep-mgems/python_derep/218_ref_pp_database_clusters.csv")
        DEREP_GROUPS(poppunk_clusters_csv, poppunk_dists_ch)

    //    ref_groups_ch = ORDER_GROUPS(pp_input_ch,poppunk_ch.out.clusters).groups
    //    index_prefix_ch = channel.value("index") // needs to be identical to what index is set as in indexing process
    //    index_files_ch = THEMISTO_BUILD_INDEX(index_prefix_ch, references_ch).collect()
        
    //    // Output stats on the index (not required for anything just an additional output)
    //    THEMISTO_STATS(index_files_ch, index_prefix_ch)

// --- REMOVE THIS SECTION ONCE TESTED --- //
//   }
// --- TO HERE--- //

//    } else {
//         // Set up input channels starting from pre-built index AND provided ref_groups
//        ref_groups_ch = channel.fromPath(params.ref_groups).first()
//        index_files_ch = channel.fromPath("${params.themisto_index}*").collect()
//        index_prefix_ch = channel.value(file(params.themisto_index).getName())

//         // Validate inputs to ensure compatibility (kmer size, number of refs)
//        def len_ref_groups = file(params.ref_groups).readLines().findAll { it.trim() }.size()
       
//        THEMISTO_STATS(index_files_ch, index_prefix_ch)
//            .map { file ->
//                def lines = file.readLines()

//                def kmer_index = lines.find { it.startsWith('Node length k:') }
//                                    .tokenize(':')[1].trim().toInteger()

//                def range = lines.find { it.startsWith('Color id range:') }
//                                .split(':')[1].trim()
//                                .split('\\.\\.')

//                def refs_index = range[1].toInteger() - range[0].toInteger() + 1

//                tuple(kmer_index, refs_index)
//            }
//            .map { kmer_index, refs_index ->
//                validate_index(kmer_index, params.kmer_size)
//                validate_ref_groups(refs_index, len_ref_groups)
//                tuple(kmer_index, refs_index)
//            }
//    }

//     // Core Workflow
//    pseudoaligned_ch = THEMISTO_PSEUDOALIGN(reads_ch,index_files_ch,index_prefix_ch)
    
//    msweep_ch = MSWEEP(pseudoaligned_ch,ref_groups_ch)
    
//   MGEMS(
//    reads_ch
//    .join(pseudoaligned_ch, by: 0)
//    .join(msweep_ch, by: 0)
//    .map { meta, r1, r2, aln1, aln2, abund, probs ->
//        tuple(meta, r1, r2, aln1, aln2, abund, probs)
//    },
//    index_files_ch,
//    index_prefix_ch,
//    ref_groups_ch
//   )
}
