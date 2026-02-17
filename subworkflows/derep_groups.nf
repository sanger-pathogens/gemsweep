include { COLLECT_FILE                 } from '../modules_derep/collect_file.nf'
include { SKETCH_SUBSET_TOTAL_ANI_DIST;
          GENERATE_TOTAL_DIST_MATRIX   } from '../modules_derep/sketchlib.nf'
include { SUBSELECT_GRAPH               } from '../modules_derep/plotting.nf'

workflow DEREP_GROUPS {
    take:
    clusters_csv
    pp_dist_matrix
    // sketchlib_db_ch

    main:
    clusters_csv
    | splitCsv(header: true)
    | map { row -> [row.Taxon, row.Cluster] }
    | groupTuple(by:1)
    | branch {
        single: it[0].size() == 1
        multiple: it[0].size() > 1
    }
    | set { clusters }

    clusters.multiple
    | transpose
    | collectFile { sample, cluster ->
        [ "multiple_samples.csv", [sample, cluster].join(",") + "\n" ]
    }
    | set { clusters_multiple_samples }


    // SKETCH_SUBSET_TOTAL_ANI_DIST(multiple_samples, sketchlib_db_ch)
    // | GENERATE_TOTAL_DIST_MATRIX
    // | SUBSELECT_GRAPH

    // SUBSELECT_GRAPH.out.representatives
    // | splitCsv()
    // | mix(single_samples)
    // | ifEmpty { error("Error: No representatives found for any bin") }
    // | set { chosen_representatives }

    // bin2channel
    // | join(chosen_representatives)
    // | set { final_dataset }
}