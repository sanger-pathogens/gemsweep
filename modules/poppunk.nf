process PREP_REFS {
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'
    tag "${meta.ID}"

    input:
    tuple val(meta), path(refs_txt)

    output:
    tuple val(meta), path('references.tsv'), emit: refs_tsv

    script:
    """
    sed -i '/^\s*\$/d' "${refs_txt}"    # Remove blank lines
    python3 ${projectDir}/bin/poppunk_helper.py --input ${refs_txt} --outdir .
    """
}

process POPPUNK {
    label 'cpu_4'
    label 'mem_16'
    label 'time_queue_from_normal'
    tag "${meta.ID}"

    container 'quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0'

    publishDir "${params.outdir}/clustering/${meta.ID}", mode: 'copy', pattern: 'pp_database/*', enabled: params.publish_poppunk

    input:
    tuple val(meta), path(refs_tsv)

    output:
    tuple val(meta), path("${out}/${out}_clusters.csv"), emit: clusters     // for downstream
    tuple val(meta), path("${out}/${out}.dists.npy"),    emit: dist_matrix
    tuple val(meta), path("${out}/*")                                       // for publishing

    script:
    out = "pp_database"

    """
    poppunk --create-db --output ${out} --r-files ${refs_tsv} --threads ${task.cpus}
    poppunk --fit-model ${params.poppunk_model} --ref-db ${out} --threads ${task.cpus}
    """
}

process ORDER_GROUPS {
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'
    tag "${meta.ID}"

    publishDir "${params.outdir}/clustering/${meta.ID}", mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(refs_tsv), path(clusters_csv)


    output:
    tuple val(meta), path("groups.txt"), emit: groups

    script:
    order_groups = "${projectDir}/bin/order_groups.py"
    if (params.cluster_dist == "core") {
        order_groups += " --poppunk_style_labels"
        }

    
    """
    ${order_groups} --references_tsv ${refs_tsv} --groups_csv ${clusters_csv} --outdir .
    """
}