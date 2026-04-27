process SKETCHLIB_SKETCH {
    label 'cpu_4'
    label 'mem_1'
    label 'time_queue_from_small'

    container 'quay.io/sangerpathogens/pp-sketchlib-python:2.1.5'

    input:
    path(refs_tsv) // has shape 'name  file.fasta' per line

    output:
    tuple path(refs_tsv), path("${sketch_db}.h5")

    script:
    sketch_db = "references_sketch" // need to make this per taxon if this runs per taxon after sylph

    // Add random match chances calcs for correction only when there are enough references to do so:
    def num_refs = refs_tsv.readLines().findAll { line -> line.trim() }.size()
    def random_match_calcs = (num_refs > 5) ? "sketchlib add random ${sketch_db}" : ""

    """
	sketchlib sketch \
		-l ${refs_tsv} \
		-o "${sketch_db}" \
		-k "${params.sketchlib_kstep}" \
		--cpus "${task.cpus}"

    ${random_match_calcs}
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
    // Check number of references is suitable for random match correction
    def num_refs = refs_tsv.readLines().findAll { line -> line.trim() }.size()

    // Add conditional flags to command
    def sketchlib_cluster = "${projectDir}/bin/sketchlib_cluster.py" 
    if (params.cluster_strict) {
        sketchlib_cluster += " --strict_mode"
        }
    if (num_refs > 5) {
        sketchlib_cluster += " --random_correct"
    }

    // reuse the sketch name for the clusters csv output
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