process MGEMS {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_2'
    label 'time_12'

    container 'quay.io/biocontainers/mgems:1.3.3--h13024bc_2'
    
    publishDir mode: 'copy', path: "${params.outdir}/${meta.ID}"

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
    tuple val(meta), path("${out}/*")

    script:
    out = "mGEMS"
    command = "mGEMS -r ${reads_1},${reads_2} --themisto-alns ${pseudoalignment_1},${pseudoalignment_2} -o ${out} --probs ${msweep_probs} -a ${msweep_abundances} --index . -i ${reference_groups}"
    if (params.get_assignments) {
        // if user wants the read assignment table used by mgems to be output, add to command
        command += " --write-assignment-table"
        }
    if (params.min_abundance != 0) {
        // create bins for groups with relative abundance above a certain threshold, user can turn off with 0
        command += " --min-abundance ${params.min_abundance}"
    }

    """
    mkdir ${out}
    ${command}
    for f in ${out}/*.fastq.gz; do
        base=\$(basename "\$f")
        mv "\$f" "${out}/${meta.ID}_\${base}"
    done
    """
}