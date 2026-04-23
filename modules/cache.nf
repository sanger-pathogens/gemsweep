// calls check_cache.py to create or validate a config-specific cache directory, write cache metadata, and emit cache_config.json 
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



/*
Then CACHE_LOOKUP and PUBLISH_CACHE_ENTRY should consume that cache_config.json instead of directly using params.cache_dir.

This is cleaner than doing it in Groovy because Python handles JSON and path logic more readably.

CACHE_LOOKUP
  reads cache_config.json
  looks under effective_cache_dir/species/<species_id>/

PUBLISH_CACHE_ENTRY
  reads cache_config.json
  writes to effective_cache_dir/species/<species_id>/


process CACHE_LOOKUP{
    // call resolve cache output which will pass in the sylph output here if it passed the checks
    // run the python script to check the cache and split into hits and misses
    //  clean outputs:
        //   - cached representatives
        //   - cached groups
        //   - uncached references (for the next step in the pipeline to compute)
    // emit outputs back into main.nf for the next steps in the pipeline to use
    // rename the python script resolve_cache.py to something more descriptive like cache_lookup.py since its specific to this now
}
workflow CACHE {
    // channel shaping wrapper around that decision
    
//  clean outputs:
//   - cached representatives
//   - cached groups
//   - uncached references (for the next step in the pipeline to compute)

    take:
    references_ch

    main:
    RESOLVE_CACHE(references_ch)

    cached_representatives_ch = RESOLVE_CACHE.out.hits
        | splitCsv(header: true, sep: '\t')
        | map { row ->
            tuple([ID: row.species_id], file(row.cached_refs))
        }

    cached_groups_ch = RESOLVE_CACHE.out.hits
        | splitCsv(header: true, sep: '\t')
        | map { row ->
            tuple([ID: row.species_id], file(row.cached_groups))
        }

    uncached_references_ch = RESOLVE_CACHE.out.misses
        | splitCsv(header: true, sep: '\t')
        | map { row ->
            tuple([ID: row.species_id], file(row.sylph_refs))
        }

    emit:
    cached_rep_refs = cached_representatives_ch
    cached_ref_groups = cached_groups_ch
    uncached_refs = uncached_references_ch

}
*/


process PUBLISH_CACHE_ENTRY {

// Copies newly generated references into the cache directory
// so they can be used in future runs of the pipeline.
// should create a .json file if not existing.

    tag "${meta.ID}"

    publishDir "${params.cache_dir}/${params.cluster_tool}/${params.model_version}/${meta.ID}", mode: 'copy'

    input:
    tuple val(meta), path(refs_file), path(groups_file)

    output:
    path("references.txt"), emit: references
    path("groups.txt"), emit: groups

    script:
    """
    cp ${refs_file} references.txt
    cp ${groups_file} groups.txt
    """
}
