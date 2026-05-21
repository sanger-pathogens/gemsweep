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

    // TODO: add a container for sbwt. For now assumes sbwt is installed and available in PATH.

    publishDir mode: 'copy', path: "${params.outdir}/sbwt"

    input:
    val index_prefix
    path ggcat_unitigs

    output:
    path "${index_prefix}.sbwt", emit: sbwt
    path "${index_prefix}.lcs",  emit: lcs

    script:
    // User-provided temp storage if given otherwise use tmp workdir (since scratch is enabled)
    temp_storage_location = params.temp_dir ? params.temp_dir : "\$PWD"

    // supply less memory allocation in the command as it requires additional overhead (will likely fail if exact)
    mem_gb_param = (task.memory.toGiga() / 1.2).toInteger()

    // TODO: determine correct sbwt CLI flags. The only requirement for now is that it writes the SBWT to ${index_prefix}.sbwt.
    // TODO: I'm hardcoding 4 GiB memory to make it run on my laptop. Should use mem_gb_param instead.
    """
    sbwt build -k ${params.kmer_size} -i ${ggcat_unitigs} -o ${index_prefix} -v --temp-dir ${temp_storage_location} --build-lcs --mem-gb 4 --dedup-batches --add-revcomp --threads ${task.cpus}
    """
}
