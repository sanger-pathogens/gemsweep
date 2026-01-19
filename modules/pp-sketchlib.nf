process SKETCHLIB {
    label 'cpu_4'
    label 'mem_8'
    label 'time_12'

    container 'quay.io/biocontainers/pp-sketchlib:1.0.0--py36hb4d53aa_0'

    publishDir mode: 'copy', path: "${params.outdir}/pp-sketchlib"

    input:
    path(ref_file)

    output:
    path(groups_file)

    script:
    helper = '../bin/sketchlib_helper.py'
    """
    python3 ${helper} ${ref_file} ${params.outdir}

    sketchlib sketch -l ${params.outdir}/references.tsv -o references --cpus 4
    
    # now create the groups file
    # example ref file: 
        genomeA.fasta
        genomeB.fasta
        genomeC.fasta
        genomeD.fasta
        genomeE.fasta
    # therefore groups file:
        strainX
        strainY
        strainY
        strainX
        strainZ

    """
}