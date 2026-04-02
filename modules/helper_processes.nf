process COMBINE_REFS {
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    publishDir "${params.outdir}/ref_groups", mode: 'copy', overwrite: true

    container 'quay.io/sangerpathogens/pandas:2.2.1'

    input:
    path(refs, stageAs: "input/refs.txt")
    path(groups, stageAs: "input/groups.txt")

    output:
    path("references.txt"), emit: references
    path("groups.txt"), emit: groups

    script:
    """
    ${projectDir}/bin/combine_refs.py \\
        --refs input/refs.txt \\
        --groups input/groups.txt \\
        --outdir .
    """
}