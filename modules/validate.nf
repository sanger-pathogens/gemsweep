// Param validation:
def validate_params() {
    // accumulate any param-related error messages, error the pipeline with any/all messages together
    def validation_errors = []

    // Validate references mode (ref_mode)
    validate_choice_param("--ref_mode", params.ref_mode, ["index", "no_derep", "single_species_derep", "multi_species_derep", "sylph_autoselect"], validation_errors)
    if (!params.ref_mode) {
        validation_errors << "You must explicitly supply a mode for references to --ref_mode."
    } else {
        validate_ref_mode_param_combos(ref_mode, validation_errors)
        if (ref_mode == "index") {
            // Check required params given and paths exist
            if (!params.themisto_index || !params.ref_groups) {
                validation_errors << "You must supply both --themisto_index and --ref_groups for chosen ref_mode ${params.ref_mode}"
            } else {
                validate_path_exists("--ref_groups", params.ref_groups, validation_errors)
                validate_index_exists("--themisto_index", params.themisto_index, ["tdbg","tcolors"], validation_errors)
            }
            // Check no additional, incompatible ref params are given
            // validate_incompatible("index", ["references", "refine_refs"], validation_errors)

        } else if (ref_mode == "no_derep") {
            // Check required params given and paths exist
            if (!params.references) {
                validation_errors << "You must supply --references for chosen ref_mode ${params.ref_mode}"
            } else {
                validate_path_exists("--references", params.references, validation_errors)
                validate_references(params.references) // Checks missing/duplicates in refs
            }
            // Check no additional, incompatible ref params are given
            
        } else if (ref_mode == "single_species_derep") {
            // Check required params given and paths exist
            params.refine_refs = true // this option might even be obsolete now
            if (!params.references) {
                validation_errors << "You must supply --references for chosen ref_mode ${params.ref_mode}"
            } else {
                validate_path_exists("--references", params.references, validation_errors)
                validate_references(params.references) // Checks missing/duplicates in refs
            }
            // Check no additional, incompatible ref params are given
        } else if (ref_mode == "multispecies_derep") { //TODO
            // Check required params given and paths exist
            // Check no additional, incompatible ref params are given
        } else if (ref_mode == "sylph_autoselect") { //TODO
            // Check required params given and paths exist
            // Check no additional, incompatible ref params are given
        }
    }

    // Clustering options
    validate_choice_param("--poppunk_model", params.poppunk_model, ["dbscan","bgmm"], validation_errors)
    
    // Themisto options
    validate_choice_param("--kmer_size", params.kmer_size, [21,31,51], validation_errors)
    if (params.temp_dir != null) {
        validate_path_exists("--temp_dir", params.temp_dir, validation_errors)
    }
    // TODO: validate requested tmp space is in MB (or GB if changing) NOT CURRENTLY PARAMETERISED

    if (validation_errors) {
        validation_errors.each { log.error " - $it " }
            error("Parameters have failed validation, please review logged errors and rerun once resolved.")
    }   
}

def validate_path_exists(path_param, path_param_value, all_errors) {
    if( !file(path_param_value).exists() ) {
        all_errors << "File supplied to ${path_param} does not exist: ${path_param_value}"
    }
}

def validate_index_exists(index_param, index_param_value, suffix_list, all_errors) {
    suffix_list.each { suffix ->
        validate_path_exists(index_param, "${index_param_value}.${suffix}", all_errors)
    }
}

def validate_choice_param(flag, value, choices, all_errors) {
    def param_name = (flag - "--").replaceAll("_", " ")
    if (!choices.contains(value)) {
        all_errors << "Please specify the ${param_name} using ${flag}, must be one of ${choices}."
    }
}

def validate_incompatible(ref_mode, incompatible_params, all_errors) {
    incompatible_params.each {
        if (params[it] != null) {
            all_errors << "Your chosen ref_mode `${ref_mode}` is incompatible with the following params: ${incompatible_params}" 
        }
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
