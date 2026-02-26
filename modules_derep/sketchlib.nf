process GENERATE_TOTAL_DIST_MATRIX {
    tag "${meta.cluster}"
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
