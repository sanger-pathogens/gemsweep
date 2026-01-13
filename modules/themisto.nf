process THEMISTO_BUILD_INDEX {
    label 'cpu_16'
    label "mem_32"
    label 'time_12'
    label 'request_temp'

    // scratch used for fast node-local temp storage
    scratch true

    container 'quay.io/sangerpathogens/themisto:3.2.2'

    input:
    val index_prefix
    path references_txt

    output:
    path "${index_prefix}.*"

    script:
    index_build_params = "-k ${params.kmer_size} -i ${references_txt} -o ${index_prefix}"
    
    // User-provided temp storage if given (and not accidentally provided as 'false') otherwise use tmp workdir (since scratch is enabled)
    if (params.temp_dir && params.temp_dir != 'false') {
        temp_storage_location = (params.temp_dir)
        index_build_params += " --temp-dir ${temp_storage_location}"
    } else {
        index_build_params += " --temp-dir \$PWD"
    }

    // supply less memory allocation in the command as it requires additional overhead (will likely fail if exact)
    mem_gigas_param = (task.memory.toGiga() / 1.2).toInteger()
    index_build_params += " --mem-gigas ${mem_gigas_param}"

    """
    themisto build ${index_build_params}
    """
}

process THEMISTO_PSEUDOALIGN {
    label 'cpu_16'
    label 'mem_32'
    label 'time_12'
    label 'request_temp'

    // scratch used for fast node-local temp storage
    scratch true

    container 'quay.io/sangerpathogens/themisto:3.2.2'

    input:
    tuple val(meta), path(reads_1), path(reads_2)
    path index_files    // For staging
    val index_prefix    // For use in command

    output:
    tuple val(meta), path("pseudoalignments_1.aln.gz"), path("pseudoalignments_2.aln.gz")

    script:
    pseudoalignment_params = "-i ${index_prefix} --n-threads ${task.cpus} --sort-output-lines --gzip-output"

    // User-provided temp storage if given (and not accidentally provided as 'false') otherwise use tmp workdir (since scratch is enabled)
    if (params.temp_dir && params.temp_dir != 'false') {
        temp_storage_location = (params.temp_dir)
        pseudoalignment_params += " --temp-dir ${temp_storage_location}"
    } else {
        pseudoalignment_params += " --temp-dir \$PWD"
    }
    
    """
    themisto pseudoalign -q ${reads_1} -o pseudoalignments_1.aln ${pseudoalignment_params}
    themisto pseudoalign -q ${reads_2} -o pseudoalignments_2.aln ${pseudoalignment_params}
    """
}

process THEMISTO_STATS {
    label 'cpu_1'
    label "mem_1"
    label 'time_1'

    container 'quay.io/sangerpathogens/themisto:3.2.2'

    publishDir mode: 'copy', path: "${params.outdir}/themisto"

    input:
    path index_files    // For staging
    val index_prefix    // For use in command

    output:
    path "index_report.txt"

    script:
    """
    themisto stats -i ${index_prefix} > "index_report.txt"
    """
}