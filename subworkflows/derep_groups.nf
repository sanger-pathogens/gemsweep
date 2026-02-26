include { SPLIT_DIST_MATRIX           } from '../modules_derep/split_dist_matrix.nf'
include { GENERATE_TOTAL_DIST_MATRIX  } from '../modules_derep/sketchlib.nf'
include { SUBSELECT_GRAPH             } from '../modules_derep/plotting.nf'

workflow DEREP_GROUPS {
    take:
    clusters_csv
    pp_dist_matrix

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

    SPLIT_DIST_MATRIX(pp_dist_matrix, clusters_multiple_samples)

    SPLIT_DIST_MATRIX.out.cluster_dists
    | flatten
    | map { path ->
        def meta = [:]
        meta.cluster = path.name.split("_")[0]
        [meta, path]
    }
    | GENERATE_TOTAL_DIST_MATRIX
    | SUBSELECT_GRAPH
    
    clusters.single
    | map { rep, cluster -> 
        def meta = [:]
        meta.cluster = cluster
        [meta, rep[0]]
    }
    | set { single_representatives }

    SUBSELECT_GRAPH.out.representatives
    | splitCsv()
    | map { meta, reps -> 
        [[meta, reps[0]]]
    }
    | collect
    | flatMap
    | mix(single_representatives)
    | ifEmpty { error("Error: No representatives found") }
    | set { chosen_representatives }

    emit:
    chosen_representatives
}