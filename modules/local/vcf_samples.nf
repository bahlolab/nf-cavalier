
process VCF_SAMPLES {
    label 'C2M2T2'
    label 'bcftools'
    /*
        Extract sample IDs from a VCF/BCF header (no index required).
        Output consumed by check_samples.R.
    */
    input:
    path(vcf)

    output:
    path(out)

    script:
    out = vcf.name.replaceAll(/\.(vcf\.gz|vcf\.bgz|vcf|bcf)$/, '') + '.samples.txt'
    """
    bcftools query -l $vcf > $out
    """
}
