
/* ----------- funtions ----------------*/
include { vcf_channel } from '../../functions/channels'

/* ----------- subworkflows ----------------*/
include { SHORT } from '../../subworkflows/local/short'
include { STRUC } from '../../subworkflows/local/struc'

workflow ANNOTATE {
    /*
        - Clean and Annotate VCFs prior to cavalier
    */
    take:
    vcfanno_binary
    check
    
    main:
    short_vcf = Channel.empty()
    struc_vcf = Channel.empty() // TODO: SVs

    if (params.short_vcf_annotated) {
        println "INFO: Skipping SHORT annotation, using annotated VCF - $params.short_vcf_annotated"
        short_vcf = vcf_channel(params.short_vcf_annotated)

    } else if (params.short_vcf) {
        SHORT(
            vcf_channel(params.short_vcf),
            vcfanno_binary,
            check
        )
        short_vcf = SHORT.out
    }

    if (params.struc_vcf_annotated) {
        println "INFO: Skipping STRUC annotation, using annotated VCF - $params.struc_vcf_annotated"
        struc_vcf = vcf_channel(params.struc_vcf_annotated)

    } else if (params.struc_vcf) {
        STRUC(
            vcf_channel(params.struc_vcf),
            check
        )
        struc_vcf = STRUC.out
    }


    emit:
    short_vcf = short_vcf
    struc_vcf = struc_vcf
    
}

