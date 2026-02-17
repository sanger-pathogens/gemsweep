process SPLIT_DIST_MATRIX {
    label "cpu_1"
    label "mem_16"
    label "time_30m"

    container "quay.io/sangerpathogens/pandas:2.2.1"

    input:
    path pp_dist_matrix
    path cluster_assignments

    output:
    path "cluster_dists/*.tsv",  emit: cluster_dists
    
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