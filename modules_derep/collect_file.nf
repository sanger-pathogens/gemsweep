process COLLECT_FILE {
    tag "${meta.reference_ID}_${meta.ref_ani_bin}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'

    input:
    tuple val(samples), val(meta)

    output:
    tuple val(meta), path("samples.txt"), emit: sample_file

    script:
    """
    echo -e "${samples.join('\\n')}" > samples.txt
    """
}

