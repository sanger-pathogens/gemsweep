include { CACHE_RESOLVE as RESOLVE;
          CACHE_LOOKUP as LOOKUP    } from '../modules/cache.nf'

workflow READ_CACHE {
    take:
    sylph_refs_ch
    
    main:
    RESOLVE
    cache_config_ch = RESOLVE.out.config.first()
    LOOKUP(sylph_refs_ch, cache_config_ch)

    // Organise cached references
    // hits: [meta, cache_hits_tsv]
    LOOKUP.out.hits
    | map { meta, cache_hits_tsv -> cache_hits_tsv }
    | splitCsv(header: true, sep: '\t')
    | map { row -> tuple([ID: row.species_id], file(row.cached_ref_groups)) }
    | set { cahce_hits }

    // misses: [meta, cache_miss_tsv] -> restore the original Sylph refs by meta
    LOOKUP.out.misses
    | join(sylph_refs_ch)
    | map { meta, cache_miss_tsv, refs_file -> tuple(meta, refs_file) }
    | set { cache_misses }

    emit:
    cache_hits
    cache_misses
    config = cache_config_ch

}