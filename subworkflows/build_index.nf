include { THEMISTO_BUILD;
          THEMISTO_STATS         } from '../modules/themisto.nf'
include { THEMISTO2_BUILD;
          THEMISTO2_STATS        } from '../assorted-sub-workflows/themisto2/modules/themisto2.nf'
include { GGCAT                  } from '../assorted-sub-workflows/themisto2/modules/ggcat.nf'
include { SBWT_BUILD             } from '../assorted-sub-workflows/themisto2/modules/sbwt.nf'

workflow BUILD_INDEX {
    take:
    references // text file of paths to references to index

    main:
    meta = [ID: 'index']
    refs_ch = references.map { refs -> [meta, refs] }


    if (params.themisto2 == false) { // Use Themisto(1) modules
        index_ch = THEMISTO_BUILD(refs_ch)
        THEMISTO_STATS(index_ch)
    }

    if (params.themisto2 == true) { // Use GGCAT, SBWT and Themisto2 modules
        GGCAT(refs_ch)
        | SBWT_BUILD
    
        SBWT_BUILD.out.index.combine(refs_ch, by: 0).map { m, sbwt, lcs, refs -> [m, refs, sbwt, lcs] }
        | THEMISTO2_BUILD // expects [meta, colors, sbwt, lcs]
        | THEMISTO2_STATS

        index_ch = THEMISTO2_STATS.out.index
    }

    emit:
    index_ch = index_ch.first() // First ensures value channel emitted
}