
process SYLPH_SKETCH_ASSEMBLIES {
    label 'cpu_2'
    label 'mem_16'
    label 'time_from_queue_normal'

    publishDir "${params.outdir}/sylph/", pattern: "*.syldb", mode: 'copy', overwrite: true, enabled: params.save_sylph_sketches

    container 'gitlab-registry.internal.sanger.ac.uk/sanger-pathogens/docker-images/sylph:0.8.1--ha6fb395_0'

    input:
    path(assemblies)

    output:
    path("*.syldb"), emit: sketch

    script:
    """
    sylph sketch -t ${task.cpus} --gl ${assemblies} -k ${params.sketch_size} -d ./
    """
}

// Also tried SYLPH_PROFILE, but it still requires read data. Suggests we'd be better off using skani
process SYLPH_QUERY {
    label 'cpu_2'
    label 'mem_20'
    label 'time_from_queue_small'

    publishDir "${params.outdir}/sylph/", pattern: "*.tsv", mode: 'copy', overwrite: true

    container 'gitlab-registry.internal.sanger.ac.uk/sanger-pathogens/docker-images/sylph:0.8.1--ha6fb395_0'

    input:
    path(sketch)

    output:
    path("sylph_profile.tsv"), emit: sylph_report

    script:
    def estimate_unknown = params.sylph_estimate_unknown ? "-u" : ""
    """
    sylph query -t ${task.cpus} -o sylph_profile.tsv -k ${params.sketch_size} ${estimate_unknown} ${sketch} ${params.sylph_db}
    """
}
