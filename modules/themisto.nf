

process THEMISTO_PSEUDOALIGN {
    label 'cpu_16'
    label 'mem_32'
    label 'time_12'

    // scratch used for fast node-local temp storage
    scratch true
    clusterOptions '-R "rusage[tmp=10000]"'

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
    if (params.temp_storage && params.temp_storage != 'false') {
        temp_storage_location = (params.temp_storage)
        pseudoalignment_params += " --temp-dir ${temp_storage_location}"
    } else {
        pseudoalignment_params += " --temp-dir \$PWD"
    }
    
    """
    themisto pseudoalign -q ${reads_1} -o pseudoalignments_1.aln ${pseudoalignment_params}
    themisto pseudoalign -q ${reads_2} -o pseudoalignments_2.aln ${pseudoalignment_params}
    """
}