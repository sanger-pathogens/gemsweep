process SUBSELECT_GRAPH {
    tag "${meta.cluster}"
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
