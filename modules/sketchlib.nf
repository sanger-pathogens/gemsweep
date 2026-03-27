process SKETCH_REFS {
    label 'cpu_2'
    label 'mem_500M'
    label 'time_30m'

    container 'quay.io/sangerpathogens/pp-sketchlib-rust:0.1.2_sd28_fix'

    input:
    path(refs_tsv) // from poppunk.nf PREP_REFS? must be in form 'name  file.fasta' once per line

    output:
    tuple path(refs_tsv), path("${sketch_db}.skm"), path("${sketch_db}.skd")

    script:
    sketch_db = "references_sketch" // need to make this per taxon if this runs per taxon after sylph
    """
    sketchlib sketch -k ${params.sketchlib_kmer_size} -o ${sketch_db} -s 1024 -f ${refs_tsv} --threads ${task.cpus}
    """
}

process SKETCHLIB_CLUSTER {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/sangerpathogens/pp-sketchlib-python:2.1.5'

    input:
    tuple path(refs_tsv), path(skm), path(skd)

    output:
    path("clusters.csv"), emit: clusters_csv // TODO: need to change script to match outputs
    path("groups.txt"), emit: groups

    script:
    sketchlib_cluster = "${projectDir}/bin/sketchlib_cluster.py" 
    if (params.cluster_strict) {
        sketchlib_cluster += " --strict_mode"
        }

    def sketch_prefix = skm.baseName.replace('.skm', '')

    """
    # Get IDs only for ref_ids
    cut -f1 ${refs_tsv} > ref_ids.txt

    ${sketchlib_cluster} \
        --sketch ${sketch_prefix} \
        --ref_ids ref_ids.txt \
        --ani_threshold ${params.ani_threshold} \
        --kmer_size ${params.sketchlib_kmer_size} \
        --out ${sketch_prefix}_clusters.tsv \
        --threads ${task.cpus} \
        --log ${sketch_prefix}_sketchlib_cluster

    cut -f2 ${sketch_prefix}_clusters.tsv | tail -n +2 > groups.txt
    """
}