process SKANI_SEARCH {
    label 'cpu_2'
    label 'mem_32'
    label 'time_queue_from_normal'

    publishDir "${params.outdir}/skani/", pattern: "*.syldb", mode: 'copy', overwrite: true, enabled: params.save_sylph_sketches

    container 'quay.io/biocontainers/skani:0.3.1--ha6fb395_0'

    input:
    path(assemblies)

    output:
    path("skani.tsv"), emit: skani_report

    script:
    """
    skani search -t ${task.cpus} --ql ${assemblies} -d ${params.skani_db} -o skani.tsv
    """
}

process GET_TOP_HITS {
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1'

    publishDir "${params.outdir}/skani/", mode: 'copy', overwrite: true

    input:
    path(skani_report)

    output:
    path(top_hits)

    script:
    top_hits = "top_hits.txt"
    filter_options = params.ani_threshold || params.aligned_frac_query || params.aligned_frac_ref ? "--filter" : ""
    filter_options += params.ani_threshold ? " --ani_threshold ${params.ani_threshold}" : ""
    filter_options += params.aligned_frac_ref ? " --aligned_frac_ref ${params.aligned_frac_ref}" : ""
    filter_options += params.aligned_frac_query ? " --aligned_frac_query ${params.aligned_frac_query}" : ""
    n_reps_option = params.n_reps ? "--n_reps ${params.n_reps}" : ""
    accession_pattern_option = params.accession_pattern ? "--accession_pattern '${params.accession_pattern}'" : ""
    """
    get_top_hits.py --skani_report ${skani_report} ${filter_options} ${n_reps_option} ${accession_pattern_option} --output .
    """
}

process GET_REFERENCES {
    label 'cpu_1'
    label 'mem_500M'
    label 'time_queue_from_small'

    container 'ubuntu:24.04'

    publishDir "${params.outdir}/skani/", mode: 'copy', overwrite: true

    input:
    path(top_hits)
    path(db_files)

    output:
    path("references.txt")

    script:
    """
    grep -f ${top_hits} ${db_files} > references.txt
    """
}
