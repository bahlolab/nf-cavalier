#!/usr/bin/env nextflow

include { validate_params } from './functions/validate'

include { SETUP    } from './workflows/setup'
include { ANNOTATE } from './workflows/annotate'
include { QC       } from './workflows/qc'
include { CAVALIER } from './workflows/cavalier'

workflow {

    validate_params()

    
    SETUP()

    QC(
        SETUP.out.check
    )

    ANNOTATE(
        SETUP.out.vcfanno_binary,
        SETUP.out.check
    )

    if (!params.annotate_only) {
        CAVALIER(
            SETUP.out.gene_set,
            SETUP.out.lists,
            SETUP.out.cavalier_opts,
            ANNOTATE.out.short_vcf,
            ANNOTATE.out.struc_vcf,
            SETUP.out.pedigree_channel,
            SETUP.out.alignment_channel,
            SETUP.out.check,
            QC.out.somalier
        )
    }

}
