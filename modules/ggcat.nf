process GGCAT {
    label 'cpu_16'
    label "mem_32"
    label 'time_queue_from_normal'

    // Only request /tmp space if /tmp is being used (assumes TMPDIR is not set)
    if (!params.temp_dir || params.temp_dir.startsWith("/tmp")) {
        label 'request_temp'
    }

    // scratch used for fast node-local temp storage
    scratch true

    // TODO: add a container for ggcat. For now assumes ggcat is installed and available in PATH.

    publishDir mode: 'copy', path: "${params.outdir}/ggcat"

    input:
    val index_prefix
    path references_txt

    output:
    path "${index_prefix}.ggcat.fa", emit: unitigs

    script:
    // User-provided temp storage if given otherwise use tmp workdir (since scratch is enabled)
    temp_storage_location = "\$PWD"
    if (params.temp_dir) {
        temp_storage_location = (params.temp_dir)
    }

    // supply less memory allocation in the command as it requires additional overhead (will likely fail if exact)
    mem_gigas_param = (task.memory.toGiga() / 1.2).toInteger()
    """
    ggcat build --input-lists ${references_txt} -o ${index_prefix}.ggcat.fa -k ${params.kmer_size} --temp-dir ${temp_storage_location} --threads-count ${task.cpus} --memory ${mem_gigas_param} --prefer-memory
    """
}
