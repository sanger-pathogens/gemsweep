process THEMISTO_BUILD_INDEX {
    label 'cpu_16'
    label "mem_32"
    label 'time_queue_from_normal'

    // Only request /tmp space if /tmp is being used (assumes TMPDIR is not set)
    if (!params.temp_dir || params.temp_dir.startsWith("/tmp")) {
        label 'request_temp'
    }

    // scratch used for fast node-local temp storage
    scratch true

    // TODO: add a container for themisto2. For now assumes themisto2 is installed and available in PATH.

    publishDir mode: 'copy', path: "${params.outdir}/themisto"


    input:
    val index_prefix
    path references_txt
    path sbwt_index
    path lcs_index

    output:
    path "${index_prefix}.*"

    script:
    index_build_params = "-k ${params.kmer_size} --file-colors ${references_txt} -o ${index_prefix}.thm2 --n-threads ${task.cpus}"

    index_build_params += " --sbwt ${sbwt_index}"
    index_build_params += " --lcs ${lcs_index}"

    // User-provided temp storage if given otherwise use tmp workdir (since scratch is enabled)
    if (params.temp_dir) {
        temp_storage_location = (params.temp_dir)
        index_build_params += " --temp-dir ${temp_storage_location}"
    } else {
        index_build_params += " --temp-dir \$PWD"
    }

    // supply less memory allocation in the command as it requires additional overhead (will likely fail if exact)
    //mem_gigas_param = (task.memory.toGiga() / 1.2).toInteger()
    //index_build_params += " --mem-gigas ${mem_gigas_param}"

    """
    themisto2 build ${index_build_params}
    """
}

process THEMISTO_PSEUDOALIGN {
    tag "${meta.ID}"
    label 'cpu_16'
    label 'mem_32'
    label 'time_12'

    // TODO: add a container for themisto2. For now assumes themisto2 is installed and available in PATH.

    input:
    tuple val(meta), path(reads_1), path(reads_2)
    path index_files    // For staging
    val index_prefix    // For use in command

    output:
    tuple val(meta), path("pseudoalignments_1.aln.gz"), path("pseudoalignments_2.aln.gz")

    script:

    pseudoalignment_params = "-i ${index_prefix}.thm2 --n-threads ${task.cpus}"

    """
    themisto2 intersection-pseudoalign -q ${reads_1} ${pseudoalignment_params} --sort-output --themisto1-output-format | gzip > pseudoalignments_1.aln.gz
    themisto2 intersection-pseudoalign -q ${reads_2} ${pseudoalignment_params} --sort-output --themisto1-output-format | gzip > pseudoalignments_2.aln.gz
    """
}

process THEMISTO_STATS {
    label 'cpu_1'
    label "mem_10"
    label 'time_1'

    // TODO: add a container for themisto2. For now assumes themisto2 is installed and available in PATH.

    publishDir mode: 'copy', path: "${params.outdir}/themisto"

    input:
    path index_files    // For staging
    val index_prefix    // For use in command

    output:
    path "index_report.txt"

    script:
    """
    themisto2 stats -i ${index_prefix}.thm2 > "index_report.txt"
    """
}
