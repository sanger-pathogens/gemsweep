process MSWEEP {
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'gitlab-registry.internal.sanger.ac.uk/sanger-pathogens/farm_installs/farm-etc/msweep/2.2.1/docker'

    input:
    tuple val(meta), path(pseudoalignment_1), path(pseudoalignment_2)
    path(ref_groups)

    output:
    tuple val(meta),
          path("${meta.id}_mSWEEP_abundances.txt"),
          path("${meta.id}_mSWEEP_probs.tsv")

    script:
    output_prefix = "${meta.id}_mSWEEP"
    command = "mSWEEP --themisto-1 ${pseudoalignment_1} --themisto-2 ${pseudoalignment_2} -o ${output_prefix} --write-probs"
    if (!params.skip_clustering) {
        // if user has skipped poppunk grouping of references, do not add to command
        command += " -i ${ref_groups}"
        }

    """
    ${command}
    """
}