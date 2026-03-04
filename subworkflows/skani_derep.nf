include { SKANI_SEARCH;
          GET_TOP_HITS;
          GET_REFERENCES            } from './modules/skani.nf'

workflow SKANI_DEREP {
    take:
    assemblies
    ref_db_files

    main:
    SKANI_SEARCH(assemblies)
    | GET_TOP_HITS
    | set { top_hits_ch }
    GET_REFERENCES(
        ref_db_files_ch,
        top_hits_ch
    )
    | set { filtered_ref_ch }

    emit:
    filtered_ref_ch
}