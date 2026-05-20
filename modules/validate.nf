// --------------------- Reusable functions ---------------------

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
    def provided = incompatible_params.findAll { params[it] != null }
    if (provided) {
        all_errors << "Your chosen ref_mode `${ref_mode}` is incompatible with the following params: ${provided.join(', ')}"
    }
}

// ---------------- Individual references validation -----------------

def validate_references(ref_paths_txt, all_errors) {
    // If the references file is missing, stop checking its contents.
    // The missing-file error is handled elsewhere.
    if (!file(ref_paths_txt).exists()) return

    // Read the references file once. raw_lines preserves the original formatting,
    // which lets us report exactly which input lines need cleanup.
    def raw_lines = file(ref_paths_txt).readLines()

    // Find lines that will be cleaned before Themisto index build.
    // This catches empty lines, whitespace-only lines, and whitespace anywhere in
    // a reference path. withIndex() lets us report human-readable line numbers.
    def lines_to_clean = raw_lines
        .withIndex()
        .findAll { line, index -> !line.trim() || line != line.replaceAll(/\s+/, '') }
        .collect { line, index -> index + 1 }

    // Warn only. Do not add this to all_errors, because these lines are cleaned
    // later before Themisto sees the references file.
    if (!lines_to_clean.isEmpty()) {
        log.warn "Empty lines or whitespace found in file supplied to --references at line(s): ${lines_to_clean.join(', ')}. These will be removed before Themisto index build."
    }

    // Build the same cleaned representation that Themisto indexing will use later.
    // Use this for duplicate and missing-file checks so validation reflects the
    // actual paths that Themisto will receive.
    def lines = raw_lines
        .collect { line -> line.replaceAll(/\s+/, '') }
        .findAll { line -> line }
    
    // Report duplicate reference paths after cleanup.
    def duplicates = lines
        .groupBy { line -> line }
        .findAll { key, values -> values.size() > 1 }
        .keySet()

    if (!duplicates.isEmpty()) {
        all_errors << "Duplicated references in ${ref_paths_txt}:\n${duplicates.join('\n')}"
    }
    // Report cleaned reference paths that do not exist on disk.
    def missing = lines.findAll { path -> !file(path).exists() }

    if (!missing.isEmpty()) {
        all_errors << "The following reference files do not exist:\n${missing.join('\n')}"
    }
}

// --------------------- Per ref_mode validation ---------------------

def validate_index_ref_mode(all_errors) {
    // Check required params given and paths exist
    if (!params.themisto_index || !params.ref_groups) {
        all_errors << "You must supply both --themisto_index and --ref_groups for chosen ref_mode ${params.ref_mode}"
    } else {
        validate_path_exists("--ref_groups", params.ref_groups, all_errors)
        validate_index_exists("--themisto_index", params.themisto_index, ["tdbg","tcolors"], all_errors)
    }
    // Check no additional, incompatible ref params are given
    validate_incompatible("index", ["references"], all_errors)
}

def validate_full_ref_mode(all_errors) {
    // Check required params given and paths exist
    if (!params.references) {
        all_errors << "You must supply --references for chosen ref_mode ${params.ref_mode}"
    } else {
        validate_path_exists("--references", params.references, all_errors)
        validate_references(params.references, all_errors) // Checks missing/duplicates in refs
    }
    if (!params.cluster_tool) {
        all_errors << "You must supply --cluster_tool for chosen ref_mode ${params.ref_mode}"
    } else {
        validate_choice_param("--cluster_tool", params.cluster_tool, ["sketchlib", "poppunk"], all_errors)
    }
    if (params.cluster_tool == "poppunk") {
        validate_choice_param("--poppunk_model", params.poppunk_model, ["dbscan","bgmm"], all_errors)

    }
    // Check no additional, incompatible ref params are given
    validate_incompatible("full", ["themisto_index", "ref_groups"], all_errors)
}

def validate_refine_ref_mode(all_errors) {
    // Check required params given and paths exist
    if (!params.cluster_tool) {
        all_errors << "You must supply --cluster_tool for chosen ref_mode ${params.ref_mode}"
    } else {
        validate_choice_param("--cluster_tool", params.cluster_tool, ["sketchlib", "poppunk"], all_errors)
    }
    if (params.cluster_tool == "poppunk") {
        validate_choice_param("--poppunk_model", params.poppunk_model, ["dbscan","bgmm"], all_errors)

    }
    if (!params.references) {
        all_errors << "You must supply --references for chosen ref_mode ${params.ref_mode}"
    } else {
        validate_path_exists("--references", params.references, all_errors)
        validate_references(params.references, all_errors) // Checks missing/duplicates in refs
    }
    // Check no additional, incompatible ref params are given
    validate_incompatible("refine", ["themisto_index", "ref_groups"], all_errors)
}

def validate_autoselect_ref_mode(all_errors) {
    // Check required params given and paths exist
    validate_path_exists("--sylph_db", params.sylph_db, all_errors)
    validate_choice_param("--sylph_k", params.sylph_k, [21,31], all_errors)
    
    // Check no additional, incompatible ref params are given
    validate_incompatible("autoselect", ["references", "themisto_index", "ref_groups"], all_errors)
}

// --------------------- Main Functions ---------------------

// Param validation:
def validate_params() {
    // accumulate any param-related error messages, error the pipeline with any/all messages together
    def validation_errors = []

    // Reference inputs
    def ref_mode_options = ["index", "full", "refine", "autoselect"]

    validate_choice_param("--ref_mode", params.ref_mode, ref_mode_options, validation_errors)

    if (params.ref_mode == "index") {
        validate_index_ref_mode(validation_errors)

    } else if (params.ref_mode == "full") {
        validate_full_ref_mode(validation_errors)

    } else if (params.ref_mode == "refine") {
        validate_refine_ref_mode(validation_errors)

    } else if (params.ref_mode == "autoselect") { 
        validate_autoselect_ref_mode(validation_errors)
    }


    // Themisto options
    validate_choice_param("--themisto_k", params.themisto_k, [21,31,51], validation_errors)
    if (params.temp_dir != null) {
        validate_path_exists("--temp_dir", params.temp_dir, validation_errors)
    }
    // TODO: validate requested tmp space is in MB (or GB if changing)

    if (validation_errors) {
        validation_errors.each { log.error " - $it " }
            error("Parameters have failed validation, please review logged errors and rerun once resolved.")
    }   
}

// Pre-built index validation:
def validate_index(kmer_index, kmer_arg) {
    if (kmer_index != kmer_arg.toInteger()) {
        error("Unexpected K-mer length for pre-built index. Please use the option '--themisto_k' in your command to supply the index's K-mer size: ${kmer_index}")
    }
}
def validate_ref_groups(num_refs_index, len_ref_groups) {
    if (num_refs_index != len_ref_groups) {
        error("Unexpected number of references assigned groups in file supplied to --ref_groups. One line per reference required, stating the cluster assigned.")
    }
}
