/* ----------- funtions ----------------*/
include { ref_fasta_channel   } from '../../functions/channels'
include { vcf_channel         } from '../../functions/channels'
include { get_vcfanno_conf    } from '../../functions/vcfanno_helpers'
include { get_vcfanno_files   } from '../../functions/vcfanno_helpers'
include { get_spliceai_files  } from '../../functions/vep_helpers'
include { get_alphamiss_files } from '../../functions/vep_helpers'
include { get_revel_files     } from '../../functions/vep_helpers'
include { get_utr_ann_files   } from '../../functions/vep_helpers'
include { get_vep_fields      } from '../../functions/vep_helpers'
include { get_vep_cache       } from '../../functions/vep_helpers'

/* ----------- processes ----------------*/
include { SCATTER      } from '../../modules/local/scatter'
include { CLEAN        } from '../../modules/local/clean'
include { VCFANNO      } from '../../modules/local/vcfanno'
include { VEP          } from '../../modules/local/vep'
include { GATHER       } from '../../modules/local/gather'

workflow SHORT {
    take: 
    vcf
    vcfanno_binary
    check

    main:
    /*
        - Preprocess and annotate SHORT/INDEL variants
    */

    SCATTER(
        vcf,
        params.short_n_shards,
        check
    )

    vcf_shards = SCATTER.out.flatMap().map{ [((it.name =~ /(?<=\.shard\.)([0-9]+)/)[0][1]), it] }
    
    CLEAN(
        vcf_shards,
        ref_fasta_channel()
    )

    VCFANNO(
            CLEAN.out,
            get_vcfanno_conf(),
            get_vcfanno_files(),
            vcfanno_binary
    )
    
    VEP(
        VCFANNO.out,
        ref_fasta_channel(),
        get_vep_cache(),
        get_spliceai_files(),
        get_alphamiss_files(),
        get_revel_files(),
        get_utr_ann_files(),
        get_vep_fields()
    )

    GATHER(
        VEP.out.toSortedList { a, b -> a.name <=> b.name }
    )   

    emit:
    GATHER.out

}

