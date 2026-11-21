// TODO: cache reolve and lookup could be done in one process since its already bottlenecked - would save a lot of nf file creation for rich metagenomic samples
process CACHE_RESOLVE {
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1' // TODO: unecessary container, only need py3

    input:
    val(user_cache_dir)
    val(ro_cache_dir)     // '' when no read-only cache is configured

    output:
    path("cache_config.json"), emit: config

    script:
    def cluster_method
    if (params.cluster_dist == "core_acc") {
        cluster_method = "${params.cluster_dist}-${params.poppunk_model}"
    } else if (params.cluster_dist == "ani") {
        cluster_method = "${params.cluster_dist}-${params.cluster_algorithm}"
    }

    def sylph_db_name = file(params.sylph_db).baseName
    def ro_cache_arg = params.read_only_cache_dir ? "--ro-cache-root '${params.read_only_cache_dir}'" : ""


    """
    ${projectDir}/bin/cache_resolve.py \\
        --ro-cache-root '${ro_cache_arg}' \\
        --user-cache-root '${params.cache_dir}' \\
        --cluster-method '${cluster_method}' \\
        --representatives '${params.representatives}' \\
        --db '${sylph_db_name}' \\
        --out cache_config.json    # TODO: rename? Seems like a misleading name
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

    container 'quay.io/sangerpathogens/pandas:2.2.1' // TODO: unecessary container, only need py3

    input:
    tuple val(meta), path(refs_file)
    path(cache_config)

    output:
    tuple val(meta), path("cache_hits.tsv"), optional: true, emit: hits
    tuple val(meta), path("cache_miss.tsv"), optional: true, emit: misses

    script:
    """
    ${projectDir}/bin/cache_lookup.py \\
        --species '${meta.ID}' \\
        --refs '${refs_file}' \\
        --cache-config '${cache_config}'
    """
}

process CACHE_WRITE {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1' // TODO: unecessary container, only need py3

    input:
    tuple val(meta), path(refs_file), path(groups_file), path(reference_clusters)
    path(cache_config)

    script:
    """
    ${projectDir}/bin/cache_write.py \\
        --species '${meta.ID}' \\
        --refs '${refs_file}' \\
        --groups '${groups_file}' \\
        --reference-clusters '${reference_clusters}' \\
        --cache-config '${cache_config}'
    """
}
