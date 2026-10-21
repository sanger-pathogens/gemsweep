
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

    container 'quay.io/biocontainers/ggcat:2.2.0--hf1b6044_0'

    publishDir mode: 'copy', path: "${params.outdir}/ggcat"

    input:
    val index_prefix
    path references_txt

    output:
    path "${index_prefix}.ggcat.fa", emit: unitigs

    script:
    index_build_params = "--input-lists ${references_txt} -o ${index_prefix}.ggcat.fa -k ${params.themisto_k} --threads-count ${task.cpus} --memory ${task.memory} --prefer-memory -s 1"

    // User-provided temp storage if given otherwise use tmp workdir (since scratch is enabled)
    if (params.temp_dir) {
        temp_storage_location = (params.temp_dir)
        index_build_params += " --temp-dir ${temp_storage_location}"
    } else {
        index_build_params += " --temp-dir \$PWD"
    }

    """
    ggcat build ${index_build_params}
    """
}