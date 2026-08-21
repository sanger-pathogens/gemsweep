include { POPPUNK                       } from '../modules/poppunk.nf'
include { SKETCHLIB_SKETCH;
          SKETCHLIB_CLUSTER             } from '../modules/sketchlib.nf'

workflow CLUSTER_REFS {
    take:
    prepared_references_tsv //output of PREP_REFS

    main:
    if (params.cluster_dist == "core_acc") {
        POPPUNK(prepared_references_tsv)
        clusters_ch    = POPPUNK.out.clusters
        dist_matrix_ch = POPPUNK.out.dist_matrix
    } else { // cluster_dist = "ani"
        SKETCHLIB_SKETCH(prepared_references_tsv)
        SKETCHLIB_CLUSTER(SKETCHLIB_SKETCH.out)
        clusters_ch    = SKETCHLIB_CLUSTER.out.clusters
        dist_matrix_ch = SKETCHLIB_CLUSTER.out.dist_matrix
    }

    emit:
    clusters    = clusters      // tuple(meta, clusters_file)
    dist_matrix = dist_matrix   // tuple(meta, dist_matrix_file)
}