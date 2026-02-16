process SKETCH_SUBSET_TOTAL_ANI_DIST {
    tag "${meta.reference_ID}_${meta.ref_ani_bin}"
    label "cpu_2"
    label "mem_1"
    label "time_30m"

    container 'quay.io/ssd28/experimental/pp-sketchlib-rust:0.1.2_sd28_fix'

    input:
    tuple val(meta), path(subset)
    tuple val(sketchlib_db), path(sketchlib_db_files)

    output:
    tuple val(meta), path("${meta.reference_ID}_${meta.ref_ani_bin}_betweenness_ani.tsv"), emit: subset_ani

    script:
    """
    sketchlib dist -v -k 17 --subset ${subset} --ani ${sketchlib_db}.skm > ${meta.reference_ID}_${meta.ref_ani_bin}_betweenness_ani.tsv
    """
}

process GENERATE_TOTAL_DIST_MATRIX {
    tag "${meta.reference_ID}_${meta.ref_ani_bin}"
    label "cpu_4"
    label "mem_8"
    label "time_1"

    container 'quay.io/ssd28/experimental/rapidnj:2.3.2-c1'

    input:
    tuple val(meta), path(betweenness_tsv)

    output:
    tuple val(meta), path("*.phylip"), emit: matrix

    script:
    def ani_tree_tools = "${projectDir}/bin/ani_tree_tools.py"
    """
    ${ani_tree_tools} --dist_tsv_path ${betweenness_tsv} --meta_ID ${meta.ref_ani_bin}
    """
}
