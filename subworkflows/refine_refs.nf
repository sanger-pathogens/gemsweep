include { SPLIT_CLUSTERS_CSV;
          SPLIT_DIST_MATRIX;
          GENERATE_TOTAL_DIST_MATRIX;
          SUBSELECT_GRAPH;
          EXTRACT_REF_LABEL;
          BUILD_REFERENCE_CLUSTER_FILES; } from '../modules/refine_refs.nf'

workflow REFINE_REFS {
    take:
    clustered_refs  // tuple(meta, references, clusters_csv, sparse_dist_matrix)

    main:
    // Idea - split clusters_csv into multiple smaller CSVs (one per cluster)
    // Then split the distance matrix per cluster - this would allow SPLIT_DIST_MATRIX to output just one CSV instead of multiple and should simplify whole workflow...

    clustered_refs
    | multiMap { meta, references, clusters_csv, dist_matrix ->
        references: [meta, references]
        clusters_csv: [meta, clusters_csv]
        dist_matrix: [meta, dist_matrix]
    }
    | set { clusters_info }

    SPLIT_CLUSTERS_CSV(clusters_info.clusters_csv)

    SPLIT_CLUSTERS_CSV.out.split_cluster_csv
    | transpose // Emit one cluster CSV file at a time
    | branch { meta, cluster_csv ->
        no_derep: cluster_csv.readLines().size() <= params.representatives
        derep: cluster_csv.readLines().size() > params.representatives
    }
    | set { clusters }

    clusters_info.dist_matrix
    | join(clusters.derep)
    | join(clusters_info.references)
    | SPLIT_DIST_MATRIX

    SPLIT_DIST_MATRIX.out.cluster_dists
    | transpose
    | map { meta, path ->
        def new_meta = [:]
        new_meta.ID = meta.ID
        new_meta.cluster = path.name.split("_")[0]
        [new_meta, path]
    }
    | GENERATE_TOTAL_DIST_MATRIX
    | SUBSELECT_GRAPH

    // Ensure we represent the genomes that are not to be dereplicated
    clusters.no_derep
    | map { meta, reps_file ->
        def new_meta = meta + ["cluster": reps_file.baseName]
        [new_meta, reps_file]
    }
    | set {clusters_no_derep}

    SUBSELECT_GRAPH.out.representatives
    | mix(clusters_no_derep)
    | collectFile { meta, rep_file ->
        def rep_lines = rep_file.readLines()
            .collect { rep_line ->
                // strip cluster col if present - rep_file is heterogeneous because it contains "rep,cluster" for clusters_no_derep and "rep" alone for SUBSELECT_GRAPH.out.representatives
                rep_line.contains(',') ? rep_line.split(',')[0] : rep_line
        }
        ["${meta.ID}_representatives.txt",rep_lines.join("\n") + "\n"]  // Add last newline to ensure last line has a newline character too!
    }
    | set { chosen_representatives }

    EXTRACT_REF_LABEL(clusters_info.references)

    chosen_representatives
    | map { chosen_representatives -> 
        def taxon = chosen_representatives.baseName.replace("_representatives", "")
        def meta = ["ID":taxon]
        [meta, chosen_representatives]
    }
    | set { chosen_representatives }

    chosen_representatives 
    | join(EXTRACT_REF_LABEL.out.ref_label_paths)
    | join(clusters_info.clusters_csv)
    | BUILD_REFERENCE_CLUSTER_FILES

    emit:
    rep_refs_and_groups = BUILD_REFERENCE_CLUSTER_FILES.out.reference_clusters
    representatives_ch = BUILD_REFERENCE_CLUSTER_FILES.out.references
    ref_groups_ch = BUILD_REFERENCE_CLUSTER_FILES.out.clusters
}
