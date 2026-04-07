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
    tuple val(meta), path(pp_dist_matrix), path(cluster_assignments)

    output:
    tuple val(meta), path("cluster_dists/*.tsv"),  emit: cluster_dists
    
    script:
    get_submatrix_script = "${workflow.projectDir}/bin/get_submatrix.py"
    """
    ${get_submatrix_script} \
        --matrix ${pp_dist_matrix} \
        --clusters ${cluster_assignments} \
        --references ${params.references} \
        --outdir cluster_dists
    """
}