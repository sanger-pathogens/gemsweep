// Param validation:
// // validate index +ref groups OR references have been provided
// if ( (params.ref_groups && params.index) == (params.references != null) ) {
//     error "Provide either --ref_groups + --index OR --references"
// }

// validate kmer_size is one of 21|31|51
// validate tmp space is in MB (or GB if changing)
// validate that temp_dir is a existing/valid path

// Pre-built index validation:
def validate_index(kmer_index, kmer_arg) {
    if (kmer_index != kmer_arg) {
        log.error("Unexpected K-mer length for pre-built index. Please use the option '--kmer_size' in your command to supply the index's K-mer size: ${kmer_index}")
        return 1
    }
}