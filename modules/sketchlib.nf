process SKETCHLIB_SKETCH {
    label 'cpu_2'
    label 'mem_500M'
    label 'time_30m'

    container 'quay.io/sangerpathogens/pp-sketchlib-python:2.1.5'

    input:
    path(refs_tsv) // has shape 'name  file.fasta' per line

    output:
    tuple path(refs_tsv), path("${sketch_db}.h5")

    script:
    sketch_db = "references_sketch" // need to make this per taxon if this runs per taxon after sylph
    """
	sketchlib sketch \
		-l ${refs_tsv} \
		-o "${sketch_db}" \
		-k "${params.sketchlib_kstep}" \
		--cpus "${task.cpus}"

    # Add random match chances calcs for correction
    sketchlib add random "${sketch_db}"
    """
}

process SKETCHLIB_CLUSTER {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/sangerpathogens/pp-sketchlib-python:2.1.5'

    input:
    tuple path(refs_tsv), path(h5_db)

    output:
    path("${sketch_prefix}_clusters.csv"), emit: clusters_csv
    path("groups.txt"), emit: groups

    script:
    sketchlib_cluster = "${projectDir}/bin/sketchlib_cluster.py" 
    if (params.cluster_strict) {
        sketchlib_cluster += " --strict_mode"
        }

    sketch_prefix = h5_db.baseName

    """
    # Get IDs only for ref_ids
    cut -f1 ${refs_tsv} > ref_ids.txt

    ${sketchlib_cluster} \
        --sketch ${sketch_prefix} \
        --ref_ids ref_ids.txt \
        --ani_threshold ${params.ani_threshold} \
        --kstep ${params.sketchlib_kstep} \
        --out ${sketch_prefix}_clusters.csv \
        --threads ${task.cpus} \
        --log ${sketch_prefix}_sketchlib_cluster

    cut -f2 ${sketch_prefix}_clusters.csv | tail -n +2 > groups.txt
    """
}