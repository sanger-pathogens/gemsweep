process SYLPH_SKETCH_DB {
    label 'cpu_2'
    label 'mem_16'
    label 'time_from_queue_normal'

    publishDir "${params.outdir}/sylph/", pattern: "*.syldb", mode: 'copy', overwrite: true, enabled: params.save_sylph_sketches

    container 'gitlab-registry.internal.sanger.ac.uk/sanger-pathogens/docker-images/sylph:0.8.1--ha6fb395_0'

    input:
    path(assemblies)

    output:
    path("*.syldb"), emit: db_sketch

    script:
    """
    sylph sketch -t ${task.cpus} --gl ${assemblies} -k ${params.sketch_size} -d ./
    """
}


// Sylph Version >=0.6 you can do direct profiling of paired-end reads without sketching 
// profile: uses the ANI and k-mers to determine which species are in the sample and their abundances
// profile basically runs a large-scale version of query automatically across the database.

process SYLPH_PROFILE_PRIMARY {
    label 'cpu_2'
    label 'mem_20'
    label 'time_from_queue_small'

    publishDir "${params.outdir}/sylph/", pattern: "*_sylph_profile.tsv", mode: 'copy', overwrite: true

    container 'gitlab-registry.internal.sanger.ac.uk/sanger-pathogens/docker-images/sylph:0.8.1--ha6fb395_0'

    input:
    tuple val(meta), path(read1), path(read2)
    path(sylph_db)

    output:
    tuple val(meta), path("${meta.ID}_sylph_profile.tsv"), emit: sylph_report

    script:
    // if -u is present then it detects how many reads don’t match the reference database well enough and 
    // Adjusts abundance estimates of known genomes to account for that missing fraction.
    // unknown reads remain unknown
    // i dont think it should be a params, or it should always be set to on
    """
    sylph profile -t ${task.cpus} -u -1 ${read1} -2 ${read2} -k ${params.sketch_size} ${sylph_db} -o ${meta.ID}_sylph_profile.tsv
    """
}

process SYLPH_SUMMARIZE {
    label 'cpu_1'
    label 'mem_4'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pandas:2.2.1'

    publishDir "${params.outdir}/sylph/", mode: 'copy', overwrite: true

    input:
    path(sylph_reports)

    output:
    path("primary_references.txt"), emit: primary_references
    path("secondary_references.txt"), emit: secondary_references
    path("sylph_summary.tsv"), emit: sylph_summary

    script:
    """
    sylph_summarize.py \
        --reports ${sylph_reports} \
        --primary-ani ${params.sylph_primary_ani} \
        --primary-cov ${params.sylph_primary_cov} \
        --secondary-ani ${params.sylph_secondary_ani} \
        --secondary-cov ${params.sylph_secondary_cov} \
        --ani-column Adjusted_ANI \
        --cov-column Eff_cov \
        --out-primary primary_references.txt \
        --out-secondary secondary_references.txt \
        --out-summary sylph_summary.tsv
    """
}
