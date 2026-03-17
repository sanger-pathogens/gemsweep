process SKETCHLIB_CLUSTER {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    input:
    tuple path(refs_txt), path(sketch) // TODO: sketch is 2 files skm and skd

    output:
    path("clusters.csv"), emit: clusters_csv // TODO: need to change to match outputs
    path("groups.txt"), emit: groups

    script:
    sketchlib_cluster = "${projectDir}/bin/sketchlib_cluster.py" 
    if (params.cluster_strict) {
        sketchlib_cluster += " --strict_mode"
        }

    //TODO: def sketch_prefix ...

    """
    ${sketchlib_cluster} \
        --sketch ${sketch_prefix} \
        --refs_txt ${refs_txt} \
        --ani_threshold ${params.ani_threshold} \
        --kmer_size ${params.sketchlib_kmer_size} \
        --out ${sketch_prefix}_clusters.tsv \
        --threads ${task.cpus} \
        --log ${sketch_prefix}_sketchlib_cluster
    """
}