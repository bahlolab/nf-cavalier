
/* ----------- funtions ----------------*/
include { vcf_channel       } from '../../functions/channels'
include { somalier_channel  } from '../../functions/channels'
include { ref_fasta_channel } from '../../functions/channels'
include { path              } from '../../functions/helpers'


/* ----------- processes ----------------*/
include { SOMALIER } from '../../modules/local/somalier'
include { SCE_VCF  } from '../../modules/local/sce_vcf'

workflow QC {
    /*
        - Clean and Annotate VCFs prior to cavalier
    */
    take:
    check
    
    main:
    somalier = channel.value([[], [], [], [], []])

    if (params.short_vcf && params.qc_somalier) {
        SOMALIER(
            check,
            vcf_channel(params.short_vcf),
            params.ped ? path(params.ped) : [],
            ref_fasta_channel(),
            somalier_channel()
        )
        somalier = SOMALIER.out
    }

    sce = channel.value([])
    if (params.short_vcf && params.qc_sce_vcf) {
        SCE_VCF(
            check,
            vcf_channel(params.short_vcf)
        )
        sce = SCE_VCF.out
    }

    emit:
    somalier = somalier
    sce      = sce
}
