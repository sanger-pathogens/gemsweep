process POPPUNK {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0'

    publishDir "${params.outdir}/poppunk/", mode: 'copy', pattern: '*.{png,csv}'

    input:
    path ref_file

    output:
    path "${params.outdir}/groups.txt"

    script:
    command = "${projectDir}/bin/sketchlib_helper.py"
    validate = "${projectDir}/bin/validate_groups.py"
    """
    python3 ${command} ${ref_file} ${params.outdir}
    poppunk --create-db --output database --r-files ${params.outdir}/references.tsv --threads ${task.cpus}
    poppunk --fit-model ${params.poppunk_model} --ref-db database --threads ${task.cpus}
    python3 ${validate} ${params.outdir}/references.tsv ${params.outdir}/database_clusters.csv ${params.outdir}
    """
}