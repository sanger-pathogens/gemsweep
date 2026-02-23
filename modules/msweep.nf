process MSWEEP {
    label 'cpu_16'
    label 'mem_4'
    label 'time_12'

    container 'quay.io/biocontainers/msweep:2.2.1--h503566f_1'

    publishDir mode: 'copy', path: "${params.outdir}/${meta.ID}"

    input:
    tuple val(meta), path(pseudoalignment_1), path(pseudoalignment_2)
    path(ref_groups)

    output:
    tuple val(meta),
          path("${meta.ID}_mSWEEP_abundances.txt"),
          path("${meta.ID}_mSWEEP_probs.tsv")

    script:
    output_prefix = "${meta.ID}_mSWEEP"
    command = "mSWEEP --themisto-1 ${pseudoalignment_1} --themisto-2 ${pseudoalignment_2} -o ${output_prefix} -i ${ref_groups} --write-probs -t ${task.cpus}"

    """
    ${command}
    """
}
