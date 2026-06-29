
process SCE_VCF {
    label 'C2M4T2'
    container 'ghcr.io/jemunro/sce-vcf:2026-03-24'
    publishDir "${params.outdir}/qc/", mode: 'copy'

    /*
        - Run sample contamination estimation
    */

    input:
    val(check)
    tuple path(vcf), path(tbi)

    output:
    path("sample-contamination-estimate.tsv")

    script:
    """
    sceVCF $vcf -d 10,500 -r ${params.qc_sce_chr} -o sample-contamination-estimate.tsv
    """
}
