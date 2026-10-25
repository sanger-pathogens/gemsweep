include { THEMISTO_PSEUDOALIGN;
          THEMISTO2_PSEUDOALIGN } from '../modules/themisto.nf'
include { MSWEEP                } from '../modules/msweep.nf'
include { MGEMS                 } from '../modules/mgems.nf'

workflow DEMIX_READS {

    take:
    reads_ch // firstpass: queue channel of each samples complete input reads, second: SOI bin
    index_ch // firstpass: GTDB index coloured by species, second: SOI index
    groups_ch // firstpass: GTDB species divided by group, second: SOI groups

    main:
        pseudoaligned_ch = params.themisto2 ? THEMISTO2_PSEUDOALIGN(reads_ch, index_ch) : THEMISTO_PSEUDOALIGN(reads_ch, index_ch)
        msweep_ch = MSWEEP(pseudoaligned_ch, groups_ch)
        
        MGEMS(
            reads_ch
              .join(pseudoaligned_ch, by: 0)
              .join(msweep_ch, by: 0),
            index_ch,
            groups_ch
        ). set { bins_ch }
    
    emit:
    bins_ch // firstpass: per-species binned reads per sample in a queue. second: per-group/strain binned reads per species readset, per sample

}