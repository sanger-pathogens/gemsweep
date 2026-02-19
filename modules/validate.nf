// Param validation:
    def validate_params() {
        def validation_errors = []
        // validate all params then error pipeline when all have been validated and any were incorrect

        // General options
        if (params.references) {
            validate_path_exists("--references", params.references, validation_errors)
            if (params.themisto_index) || (params.ref_groups) {
                log.warn("As references are supplied, the ref_groups and themisto_index parameters will be ignored.")
            }
        } else {
            if !(params.ref_groups) || !(params.themisto_index) {
                validation_errors << "You must supply either references or both themisto index and reference groups file."
            } else {
                validate_path_exists("--ref_groups", params.ref_groups, validation_errors)
                validate_path_exists("--themisto_index", params.themisto_index, validation_errors)
            }
        }

        // Clustering options
        validate_choice_param("--poppunk_model", params.poppunk_model, ["dbscan","bgmm"], validation_errors)
        
        // Themisto options
        validate_choice_param("--kmer_size", params.kmer_size, [21,31,51], validation_errors)

        if (validation_errors) {
            validation_errors.each { log.error " - $it " }
                error("Parameters have failed validation, please review logged errors and rerun once resolved.")
        }
        
    }

    // TODO:
    // validate tmp space is in MB (or GB if changing) NOT CURRENTLY PARAMETERISED

    def validate_path_exists(path_param, path_param_value, all_errors) {
        if( !file(path_param_value).exists() ) {
            all_errors << "File supplied to ${path_param} does not exist: ${path_param_value}"
        }
    }

    def validate_choice_param(flag, value, choices, all_errors) {
        def param_name = (flag - "--").replaceAll("_", " ")
        if (!choices.contains(value)) {
            all_errors << "Please specify the ${param_name} using ${flag}, must be one of ${choices}."
        }
    }

    def validate_mutually_exclusive(incompatible_param_1, incompatible_param_2, all_errors) {
        if (incompatible_param_1 != null && incompatible_param_2 != null) {
        all_errors << "Incompatible options ${incompatible_param_1} and ${incompatible_param_2} provided. Please remove one from the command."
        }
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

// References manifest validation:
def validate_references(ref_paths_txt) {

    def lines = file(ref_paths_txt)
        .readLines()
        .collect { line -> line.trim() }
        .findAll { line -> line }

    def duplicates = lines
        .groupBy { line -> line }
        .findAll { key, values -> values.size() > 1 }
        .keySet()

    if (!duplicates.isEmpty()) {
        error("Duplicated references in ${ref_paths_txt}:\n${duplicates.join('\n')}")
    }

    def missing = lines.findAll { path -> !file(path).exists() }

    if (!missing.isEmpty()) {
        error("The following reference files do not exist:\n${missing.join('\n')}")
    }

    return lines
}