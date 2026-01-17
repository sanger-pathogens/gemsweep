// Param validation:
// // validate index +ref groups OR references have been provided
// if ( (params.ref_groups && params.index) == (params.references != null) ) {
//     log.info "Provide either --ref_groups + --index OR --references"
// }

// validate kmer_size is one of 21|31|51
// validate tmp space is in MB (or GB if changing)
// validate that temp_dir is a existing/valid path

// Pre-built index validation:
def validate_index(kmer_index, kmer_arg) {
    if (kmer_index != kmer_arg.toInteger()) {
        error("Unexpected K-mer length for pre-built index. Please use the option '--kmer_size' in your command to supply the index's K-mer size: ${kmer_index}")
    } else {
        log.info "Confirmed that K-mer length for pre-built index matches that of --kmer_size arg."
    }
}
def validate_ref_groups(num_refs_index, len_ref_groups) {
    if (num_refs_index != len_ref_groups) {
        error("Unexpected number of references assigned groups in file supplied to --ref_groups. One line per reference required, stating the cluster assigned.")
    } else {
        log.info "Confirmed that number of references in pre-built index matches number of references assigned clusters in file supplied to --ref_groups."
    }
}