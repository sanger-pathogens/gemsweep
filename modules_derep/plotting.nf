process SUBSELECT_GRAPH {
    tag "${meta.cluster}"
    label "cpu_1"
    label "mem_16"
    label "time_30m"

    publishDir "${params.outdir}/clusters/${meta.cluster}", pattern: "*.png", mode: 'copy', overwrite: true
    publishDir "${params.outdir}/clusters/${meta.cluster}", pattern: "*.gif", mode: 'copy', overwrite: true
    publishDir "${params.outdir}/clusters/${meta.cluster}", pattern: "*.txt", mode: 'copy', overwrite: true

    container 'quay.io/sangerpathogens/python_graphics:1.1.4'

    input:
    tuple val(meta), path(phylip)

    output:
    path("*.txt"), emit: representatives, optional: true
    path("*.csv"), emit: clusters, optional: true
    path("*.png"), optional: true
    path("*.gif"), optional: true

    script:
    def make_gif = params.make_gif ? "--plot_selection_plots" : ""
    def representatives = params.representatives ? "--n_representatives ${params.representatives}" : ""
    def subselect_graph = "${projectDir}/bin/subselect_graph.py"
    """
    ${subselect_graph} --phylip ${phylip} --methods ${params.cluster_method} ${make_gif} ${representatives}
    """
}
