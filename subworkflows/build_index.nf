include { THEMISTO_BUILD_INDEX;
          THEMISTO_STATS;
          THEMISTO2_BUILD_INDEX;
          THEMISTO2_STATS        } from '../modules/themisto.nf'
include { GGCAT                  } from '../modules/ggcat.nf'
include { SBWT_BUILD             } from '../modules/sbwt.nf'

workflow BUILD_INDEX {
    take:
    references

    main:
    index_prefix = channel.value('index')


    if (params.themisto2 == false) { // Use Themisto(1) modules
    index_ch = index_prefix.join(THEMISTO_BUILD_INDEX(references))
    THEMISTO_STATS(index_ch)

    } else if (params.themisto2 == true) { // Use GGCAT, SBWT and Themisto2 modules
    GGCAT(index_prefix, references)
    SBWT_BUILD(index_prefix, GGCAT.out.unitigs)
    index_ch = index_prefix.join(THEMISTO2_BUILD_INDEX(references, SBWT_BUILD.out.sbwt, SBWT_BUILD.out.lcs_array).collect())
    THEMISTO2_STATS(index_ch)
    }

    emit:
    index_ch
}