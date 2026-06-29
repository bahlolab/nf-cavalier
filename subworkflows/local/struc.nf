/* ----------- funtions ----------------*/
include { ref_fasta_channel   } from '../../functions/channels'
include { get_vep_cache       } from '../../functions/vep_helpers'
include { get_vep_fields      } from '../../functions/vep_helpers'
include { get_svafdb          } from '../../functions/vep_helpers.nf'


/* ----------- processes ----------------*/
include { SCATTER              } from '../../modules/local/scatter'
include { CLEAN_STRUC as CLEAN } from '../../modules/local/clean'
include { SVAFOTATE            } from '../../modules/local/svafotate.nf'
include { VEP_STRUC as VEP     } from '../../modules/local/vep'
include { GATHER               } from '../../modules/local/gather'



workflow STRUC {
    take: 
    vcf
    check

    main:
    /*
        - Preprocess and annotate structural variants variants
    */

    SCATTER(
        vcf,
        params.struc_n_shards,
        check
    )

    vcf_shards = SCATTER.out.flatMap().map{ [((it.name =~ /(?<=\.shard\.)([0-9]+)/)[0][1]), it] }
    
    CLEAN(
        vcf_shards,
    )

    SVAFOTATE(
        CLEAN.out,
        get_svafdb()
    )

    VEP(
        SVAFOTATE.out,
        ref_fasta_channel(),
        get_vep_cache(),
        get_vep_fields(false)
    )

    GATHER(
        VEP.out.toSortedList { a, b -> a.name <=> b.name }
    )

    emit:
    GATHER.out
}

