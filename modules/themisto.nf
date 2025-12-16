

process THEMISTO_PSEUDOALIGN {
    label 'cpu_16'
    label params.temp_storage ? "mem_16" : "mem_120"
    label 'time_12'

    container 'quay.io/sangerpathogens/themisto:3.2.2'

    input:
    tuple val(meta), path(reads_1), path(reads_2)
    path index

    output:
    tuple val(meta), path("pseudoalignments_1.aln.gz"), path("pseudoalignments_2.aln.gz")

    script:
    pseudoalignment_params = "-i ${index} --n-threads ${task.cpus} --sort-output --gzip-output"

    if (params.temp_storage) {
        temp_storage_location = (params.temp_storage)
        // if temp storage is to be utilised in HPC environment, add to command
        pseudoalignment_params += " --temp-dir ${temp_storage_location}"
        }
    
    """
    themisto pseudoalign -q ${reads_1} -o pseudoalignments_1.aln ${pseudoalignment_params}
    themisto pseudoalign -q ${reads_2} -o pseudoalignments_2.aln ${pseudoalignment_params}
    """
}