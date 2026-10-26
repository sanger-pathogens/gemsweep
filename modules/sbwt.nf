process SBWT_BUILD {
    label 'cpu_16'
    label "mem_32"
    label 'time_queue_from_normal'

    // Only request /tmp space if /tmp is being used (assumes TMPDIR is not set)
    if (!params.temp_dir || params.temp_dir.startsWith("/tmp")) {
        label 'request_temp'
    }

    // scratch used for fast node-local temp storage
    scratch true

    container 'quay.io/sangerpathogens/sbwt:0.4.2'

    input:
    val index_prefix
    path ggcat_unitigs

    output:
    path "${index_prefix}.sbwt", emit: sbwt
    path "${index_prefix}.lcs",  emit: lcs_array

    script:
    // User-provided temp storage if given otherwise use tmp workdir (since scratch is enabled)
    temp_storage_location = params.temp_dir ? params.temp_dir : "\$PWD"

    // Jarno recommendation: at least 10% buffer
    mem_gigas_param = (task.memory.toGiga() * 0.9).toInteger()

    // TODO: remove -v (verbose) after validation
    """
    sbwt build -k ${params.themisto_k} -i ${ggcat_unitigs} -o ${index_prefix} --temp-dir ${temp_storage_location} --build-lcs --mem-gb ${mem_gigas_param} --dedup-batches --add-revcomp --threads ${task.cpus} -v
    """
}
