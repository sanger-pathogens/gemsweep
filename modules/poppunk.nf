process PREP_REFS {
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'

    input:
    path refs_txt

    output:
    path 'references.tsv', emit: refs_csv

    script:
    """
    python3 ${projectDir}/bin/poppunk_helper.py ${refs_txt} .
    """
}

process POPPUNK {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0'

    publishDir "${params.outdir}/poppunk/", mode: 'copy', pattern: 'pp_database/*', enabled: params.publish_poppunk

    input:
    path ref_tsv

    output:
    path "${out}/${out}_clusters.csv", emit: clusters     // for downstream
    path "${out}/${out}.dists.npy",    emit: dist_matrix
    path "${out}/*"                                       // for publishing

    script:
    out = "pp_database"

    """
    poppunk --create-db --output ${out} --r-files ${ref_tsv} --threads ${task.cpus}
    poppunk --fit-model ${params.poppunk_model} --ref-db ${out} --threads ${task.cpus}
    """
}

process ORDER_GROUPS {
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'

    publishDir "${params.outdir}/poppunk/", mode: 'copy', overwrite: true

    input:
    path refs_tsv
    path clusters_csv


    output:
    path "groups.txt", emit: groups
    path clusters_csv


    script:
    """
    python3 ${projectDir}/bin/order_groups.py ${refs_tsv} ${clusters_csv} .
    """
}