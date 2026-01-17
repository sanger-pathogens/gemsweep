// Param validation:
    // // validate index +ref groups OR references have been provided
    // if ( (params.ref_groups && params.index) == (params.references != null) ) {
    //     log.info "Provide either --ref_groups + --index OR --references"
    // }

    // validate kmer_size is one of 21|31|51
    def validate_choice_param(flag, value, choices) {
        def param_name = (flag - "--").replaceAll("_", " ")
        if (!choices.contains(value)) {
            log.error("Please specify the ${param_name} using ${flag}, must be one of ${choices}.")
        }
    }


// validate tmp space is in MB (or GB if changing)
// validate that temp_dir is a existing/valid path
    def validate_params() {
        // validate all params then error pipeline when all have been validated and any were incorrect.
        validate_choice_param("--kmer_size", params.kmer_size, [21,31,51])
    }

// Pre-built index validation:
def validate_index(kmer_index, kmer_arg) {
    if (kmer_index != kmer_arg.toInteger()) {
        error("Unexpected K-mer length for pre-built index. Please use the option '--kmer_size' in your command to supply the index's K-mer size: ${kmer_index}")
    }
}
def validate_ref_groups(num_refs_index, len_ref_groups) {
    if (num_refs_index != len_ref_groups) {
        error("Unexpected number of references assigned groups in file supplied to --ref_groups. One line per reference required, stating the cluster assigned.")
    }
}