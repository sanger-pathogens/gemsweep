process MGEMS {
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/biocontainers/mgems:1.3.3--h13024bc_2'
    
    publishDir mode: 'copy', path: "${params.outdir}/mgems"

    input:
    tuple val(meta),
          path(reads_1),
          path(reads_2),
          path(pseudoalignment_1),
          path(pseudoalignment_2),
          path(msweep_abundances),
          path(msweep_probs)
        path(index_files)
        val(index_prefix)
        path(reference_groups)

    output:
    tuple val(meta), path("mGEMS_out/*")

    script:
    output_file = "mGEMS_out"
    command = "mGEMS -r ${reads_1},${reads_2} --themisto-alns ${pseudoalignment_1},${pseudoalignment_2} -o ${output_file} --probs ${msweep_probs} -a ${msweep_abundances} --index . -i ${reference_groups}"
    if (params.get_assignments) {
        // if user wants the read assignment table used by mgems output, add to command
        command += " --write_assignment_table"
        }

    """
    mkdir mGEMS_out
    ${command}
    """
}