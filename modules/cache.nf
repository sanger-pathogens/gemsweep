// calls check_cache.py to create or validate a config-specific cache directory, write cache metadata, and emit cache_config.json.
process CHECK_CACHE {
    output:
    path("cache_config.json"), emit: config

    script:
    cluster_model = params.cluster_tool == "poppunk" ? params.poppunk_model : params.sketchlib_model

    """
    python3 ${projectDir}/bin/check_cache.py \\
        --cache-root '${params.cache_dir}' \\
        --cluster-tool '${params.cluster_tool}' \\
        --cluster-method '${params.cluster_method}' \\
        --cluster-model '${cluster_model ?: ""}' \\
        --representatives '${params.representatives}' \\
        --out cache_config.json
    """
}
// receives Sylph species refs
//  reads cache_config.json
//  checks actual files under effective_cache_dir/species/<species_id>/

process CACHE_LOOKUP {
    tag "${meta.ID}"

    input:
    tuple val(meta), path(refs_file)
    path(cache_config)

    output:
    path("cache_hit.tsv"), optional: true, emit: hits
    path("cache_miss.tsv"), optional: true, emit: misses

    script:
    """
    python3 ${projectDir}/bin/cache_lookup.py \\
        --species '${meta.ID}' \\
        --refs '${refs_file}' \\
        --cache-config '${cache_config}'
    """
}

process WRITE_CACHE_ENTRY {
    tag "${meta.ID}"

    input:
    tuple val(meta), path(refs_file), path(groups_file)
    path(cache_config)

    script:
    """
    python3 ${projectDir}/bin/write_cache_entry.py \\
        --species '${meta.ID}' \\
        --refs '${refs_file}' \\
        --groups '${groups_file}' \\
        --cache-config '${cache_config}'
    """
}