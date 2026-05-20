// calls check_cache.py to create or validate a config-specific cache directory, write cache metadata, and emit cache_config.json.
process CHECK_CACHE {
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1'

    output:
    path("cache_config.json"), emit: config

    script:
    if (params.cluster_dist == "core") {
        cluster_method = "${params.cluster_dist}-${params.poppunk_model}"
    } else if (params.cluster_dist == "ani") {
        cluster_method = "${params.cluster_dist}-${params.cluster_algorithm}"
    }


    """
    python3 ${projectDir}/bin/check_cache.py \\
        --cache-root '${params.cache_dir}' \\
        --cluster-method '${cluster_method}' \\
        --representatives '${params.representatives}' \\
        --out cache_config.json
    """
}
// receives Sylph species refs
//  reads cache_config.json
//  checks actual files under effective_cache_dir/species/<species_id>/

process CACHE_LOOKUP {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1'

    input:
    tuple val(meta), path(refs_file)
    path(cache_config)

    output:
    tuple val(meta), path("cache_hits.tsv"), path(refs_file), optional: true, emit: hits
    tuple val(meta), path("cache_miss.tsv"), path(refs_file), optional: true, emit: misses

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
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1'

    input:
    tuple val(meta), path(refs_file), path(groups_file), path(reference_clusters)
    path(cache_config)

    script:
    """
    python3 ${projectDir}/bin/write_cache_entry.py \\
        --species '${meta.ID}' \\
        --refs '${refs_file}' \\
        --groups '${groups_file}' \\
        --reference-clusters '${reference_clusters}' \\
        --cache-config '${cache_config}'
    """
}
