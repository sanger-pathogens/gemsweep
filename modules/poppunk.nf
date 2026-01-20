process POPPUNK {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0'

    publishDir mode: 'copy', path: "${params.outdir}/groups.txt"

    input:
    path(ref_file)

    output:
    path(groups_file)

    script:
    helper = '../bin/sketchlib_helper.py'
    validate = '../bin/validate_groups.py'
    """
    python3 ${helper} ${ref_file} ${params.outdir}
    poppunk --create-db --output database --r-files ${params.outdir}/references.tsv --threads 4
    poppunk --fit-model ${params.poppunk_model} --ref-db database
    cp database/database_clusters.csv ${params.outdir}
    python3 ${validate} ${params.outdir}/references.tsv ${params.outdir}/database_clusters.csv ${params.outdir}
    """
}