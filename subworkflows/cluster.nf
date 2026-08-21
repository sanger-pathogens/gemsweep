include { POPPUNK                       } from '../modules/poppunk.nf'
include { SKETCHLIB_SKETCH;
          SKETCHLIB_CLUSTER             } from '../modules/sketchlib.nf'

workflow CLUSTER_REFS {
    take:
    prepared_references_tsv //output of PREP_REFS

    main:
    if (params.cluster_dist == "core_acc") {
        POPPUNK(prepared_references_tsv)
        clusters    = POPPUNK.out.clusters
        dist_matrix = POPPUNK.out.dist_matrix
    } else { // cluster_dist = "ani"
        SKETCHLIB_SKETCH(prepared_references_tsv)
        SKETCHLIB_CLUSTER(SKETCHLIB_SKETCH.out)
        clusters    = SKETCHLIB_CLUSTER.out.clusters
        dist_matrix = SKETCHLIB_CLUSTER.out.dist_matrix
    }

    emit:
    clusters      // tuple(meta, clusters_csv)
    dist_matrix   // tuple(meta, dist_matrix_file)
}