process SKETCHLIB_SKETCH {
    label 'cpu_4'
    label 'mem_1'
    label 'time_queue_from_small'
    tag "${meta.ID}"

    container 'quay.io/sangerpathogens/pp-sketchlib-python:2.1.5-c1'

    input:
    tuple val(meta), path(refs_tsv) // has shape 'name  file.fasta' per line

    output:
    tuple val(meta), path(refs_tsv), path("${sketch_db}.h5")

    script:
    sketch_db = "${meta.ID}_sketch"

    """
	sketchlib sketch \
		-l ${refs_tsv} \
		-o "${sketch_db}" \
		-k ${params.sketchlib_kstep} \
		--cpus "${task.cpus}"

    # Add random match chances calcs for correction only when there are enough references to do so
    num_refs=\$(grep -cve '^\\s*\$' ${refs_tsv})
    if [ "\$num_refs" -gt 5 ]; then
        sketchlib add random "${sketch_db}"
    fi
    """
}

process SKETCHLIB_CLUSTER {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'
    tag "${meta.ID}"

    container 'quay.io/sangerpathogens/pp-sketchlib-python:2.1.5-c1'

    input:
    tuple val(meta), path(refs_tsv), path(h5_db)

    output:
    tuple val(meta), path("${meta.ID}_clusters.csv"), emit: clusters
    tuple val(meta), path("${meta.ID}.dists.npy"),    emit: dist_matrix // for interoperability with refine_refs

    script:
    def sketchlib_cluster = "${projectDir}/bin/sketchlib_cluster.py" 
    if (params.cluster_strict) {
        sketchlib_cluster += " --strict_mode"
        }

    sketch_prefix = h5_db.baseName

    """
    # Get IDs only for ref_ids
    cut -f1 ${refs_tsv} > ref_ids.txt

    # Get number of references to determine whether to use random match calcs
    num_refs=\$(grep -cve '^\\s*\$' ${refs_tsv})
    random_flag=""
    if [ "\$num_refs" -gt 5 ]; then
        random_flag="--random_correct"
    fi

    ${sketchlib_cluster} \
        --sketch ${sketch_prefix} \
        --ref_ids ref_ids.txt \
        --ani_threshold ${params.ani_threshold} \
        --kstep ${params.sketchlib_kstep} \
        --out_prefix ${meta.ID} \
        --threads ${task.cpus} \
        --log ${meta.ID}_sketchlib_cluster \
        --algorithm ${params.cluster_algorithm} \
        \$random_flag

    """
}