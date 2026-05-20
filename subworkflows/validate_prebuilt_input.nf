#!/usr/bin/env nextflow
// Copyright (C) 2024 Genome Research Ltd.
// Processes
include { THEMISTO_STATS      } from '../modules/themisto.nf'

// Helper Functions
include { validate_index;
          validate_ref_groups } from '../modules/validate.nf'

workflow VALIDATE_PREBUILT_INPUT {
    // Validation of reference-related inputs for the entry point taking prebuilt reference index and clusters file
    // to ensure compatibility (kmer size, number of refs)

    take:
    index_files_ch
    index_prefix_ch

    main:
    def len_ref_groups = file(params.ref_groups).readLines().findAll { it.trim() }.size()
    
    THEMISTO_STATS(index_files_ch, index_prefix_ch)
    .map { file ->
        def lines = file.readLines()

        def kmer_index = lines.find { it.startsWith('Node length k:') }
                            .tokenize(':')[1].trim().toInteger()

        def range = lines.find { it.startsWith('Color id range:') }
                        .split(':')[1].trim()
                        .split('\\.\\.')

        def refs_index = range[1].toInteger() - range[0].toInteger() + 1

        tuple(kmer_index, refs_index)
    }
    .map { kmer_index, refs_index ->
        validate_index(kmer_index, params.themisto_k)
        validate_ref_groups(refs_index, len_ref_groups)
        tuple(kmer_index, refs_index)
    }
}