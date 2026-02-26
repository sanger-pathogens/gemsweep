process PUBLISH_REPS {
    // Publish the representative reference genomes selected in a text file
    // Enables rerunning with intermediate entrypoint --themisto_index and --ref_groups

    label 'cpu_50M'
    label "mem_1"
    label 'time_30m'

    publishDir "${params.outdir}/poppunk_representatives", mode: 'copy'

    input:
    path(representatives)

    output:
    path("representatives.txt")

    script:
    """
    cp ${representatives} representatives.txt
    """
}

process PUBLISH_GROUPS {
    // Publish the representative reference genomes groups assignment file when dereplicating references
    // Enables rerunning with intermediate entrypoint --themisto_index and --ref_groups
    
    label 'cpu_50M'
    label "mem_1"
    label 'time_30m'

    publishDir "${params.outdir}/poppunk_representatives", mode: 'copy'

    input:
    path(representative_groups)

    output:
    path("groups.txt")

    script:
    """
    cp ${representative_groups} groups.txt
    """
}