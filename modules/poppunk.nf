process POPPUNK {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/biocontainers/poppunk:2.7.8--py310h4d0eb5b_0'

    publishDir "${params.outdir}/poppunk/", mode: 'copy', pattern: 'pp_database/*.{png,csv,txt}'

    input:
    path ref_file

    output:
    path "${out}/groups.txt"

    script:
    out = "pp_database"
    command = "${projectDir}/bin/sketchlib_helper.py"
    validate = "${projectDir}/bin/validate_groups.py"
    """
    python3 ${command} ${ref_file} .
    poppunk --create-db --output ${out} --r-files references.tsv --threads ${task.cpus}
    poppunk --fit-model ${params.poppunk_model} --ref-db ${out} --threads ${task.cpus}
    python3 ${validate} references.tsv ${out}/${out}_clusters.csv ${out}
    """
}