process SPLIT_CLUSTERS_CSV {
    tag "${meta.ID}"
    label "cpu_1"
    label "mem_1"
    label "time_queue_from_small"

    container "quay.io/sangerpathogens/pandas:2.2.1"

    input:
    tuple val(meta), path(cluster_assignments)

    output:
    tuple val(meta), path("clusters/*.csv"),  emit: split_cluster_csv

    script:
    split_clusters_csv_script = "${workflow.projectDir}/bin/split_clusters_csv.py"
    """
    ${split_clusters_csv_script} \\
        --outdir clusters \\
        --clusters ${cluster_assignments} \\
        --header
    """
}

process SUBSELECT_GRAPH {
    tag "${meta.ID} - cluster ${meta.cluster}"
    label "cpu_1"
    label "mem_16"
    label "time_30m"

    container 'quay.io/sangerpathogens/python_graphics:1.1.4'

    input:
    tuple val(meta), path(phylip)

    output:
    tuple val(meta), path("*.txt"), emit: representatives, optional: true

    script:
    def representatives = params.representatives ? "--n_representatives ${params.representatives}" : ""
    def subselect_graph = "${projectDir}/bin/subselect_graph.py"
    """
    ${subselect_graph} --phylip ${phylip} --methods ${params.cluster_method} ${representatives}
    """
}

process GENERATE_TOTAL_DIST_MATRIX {
    tag "${meta.ID} - cluster ${meta.cluster}"
    label "cpu_4"
    label "mem_8"
    label "time_1"

    container 'quay.io/ssd28/experimental/rapidnj:2.3.2-c1'

    input:
    tuple val(meta), path(betweenness_tsv)

    output:
    tuple val(meta), path("*.phylip"), emit: matrix

    script:
    def ani_tree_tools = "${projectDir}/bin/ani_tree_tools.py"
    """
    ${ani_tree_tools} --dist_tsv_path ${betweenness_tsv} --meta_ID ${meta.cluster} --core_accession --header
    """
}

process SPLIT_DIST_MATRIX {
    tag "${meta.ID}"
    label "cpu_1"
    label "mem_16"
    label "time_queue_from_small"

    container "quay.io/sangerpathogens/pandas:2.2.1"

    input:
    tuple val(meta), path(dist_matrix), path(cluster_assignments), path(references)

    output:
    tuple val(meta), path("cluster_dists/*.tsv"),  emit: cluster_dists

    script:
    get_submatrix_script = "${workflow.projectDir}/bin/get_submatrix.py"
    // If poppunk has sanitised the ref_labels this flag accounts for that
    if (params.cluster_dist == "core_acc") {
        get_submatrix_script += " --poppunk_style_labels"
        }
    
    """
    ${get_submatrix_script} \
        --matrix ${dist_matrix} \
        --clusters ${cluster_assignments} \
        --references ${references} \
        --outdir cluster_dists
    """
}

process EXTRACT_REF_LABEL {
    tag "${meta.ID}"
    label "cpu_1"
    label "mem_1"
    label "time_queue_from_small"

    container "quay.io/sangerpathogens/pandas:2.2.1"

    input:
    tuple val(meta), path(references)

    output:
    tuple val(meta), path(output_csv),  emit: ref_label_paths

    script:
    output_csv = "${meta.ID}_reference_paths.csv"
    extract_ref_label = "${projectDir}/bin/extract_ref_label.py"
    if (params.cluster_dist == "core_acc") {
        extract_ref_label_script += " --poppunk_style_labels"
    }

    """
    ${extract_ref_label} \\
        --references ${references} \\
        --output ${output_csv}
    """
}

process NORMALISE_REFERENCE_LIST {
    tag "${meta.ID}"
    label "cpu_1"
    label "mem_1"
    label "time_queue_from_small"

    container "quay.io/sangerpathogens/pandas:2.2.1"  // TODO Only needs to rely on ubuntu...

    input:
    tuple val(meta), path(reference_list)

    output:
    tuple val(meta), path("references.txt")

    script:
    """
    cut -d',' -f1 $reference_list > references.txt
    """
}

process BUILD_REFERENCE_CLUSTER_FILES {
    tag "${meta.ID}"
    label "cpu_1"
    label "mem_1"
    label "time_queue_from_small"

    container "quay.io/sangerpathogens/pandas:2.2.1"

    input:
    tuple val(meta), path(ref_labels), path(reference_list), path(clusters_csv)

    output:
    tuple val(meta), path("${meta.ID}_reference_clusters.csv"), emit: reference_clusters
    tuple val(meta), path("${meta.ID}_references.txt"), emit: references
    tuple val(meta), path("${meta.ID}_clusters.txt"), emit: clusters

    script:
    """
    ${projectDir}/bin/join_reference_cluster.py \
        --ref_labels ${ref_labels} \
        --reference_list ${reference_list} \
        --clusters_csv ${clusters_csv} \
        --output_prefix ${meta.ID}
    """
}
