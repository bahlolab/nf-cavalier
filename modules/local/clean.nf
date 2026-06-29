
process CLEAN {
    label 'C2M2T2'
    label 'bcftools'
    tag { i }
    /*
        Clean input VCF:
        - Filter for variants based on FILTER field
        - Drop unused annotations
        - Split multiallelics to single records and normalise representation
        - Fill AC/AF/AN if enabled
        - Drop non-variants (AF ==0) or variants with alt == '*' (GATK emits these)

        TODO: detect if fill-tags needs to be run and run it (saves time if missing)
    */

    input:
    tuple val(i), path(vcf)
    tuple path(ref), path(ref_fai)

    output:
    tuple val(i), path(output), path("${output}.tbi")

    script:
    output = vcf.name.replaceAll(/\.(vcf\.gz|vcf\.bgz|bcf)$/, '.clean.vcf.gz')
    // decrease VCF size by dropping unused fields
    remove = 'QUAL,FILTER' +
        (params.short_info    ? ',^' + params.short_info  .collect{ "INF/$it" }.join(',') : '') +
        (params.short_format  ? ',^' + params.short_format.collect{ "FMT/$it" }.join(',') : '')
    """
    bcftools view $vcf --no-version -Ou ${params.short_vcf_filter ? "-f  '$params.short_vcf_filter'": ''} \\
        | bcftools annotate --no-version -Ou --remove '$remove' \\
        | bcftools norm --no-version -Ou -m-any -f $ref \\
        ${params.short_fill_tags ? '| bcftools +fill-tags --no-version -Ou -- -t AC,AF,AN' : ''} \\
        | bcftools view -e 'AF=0 || ALT="*"' --no-version -Oz -o $output --write-index=tbi
    """
}

process CLEAN_STRUC {
    label 'C2M2T2'
    label 'bcftools'
    tag { i }
    /*
        Clean input VCF:
        - Filter for variants based on FILTER field
        - Drop unused annotations
        - Split multiallelics to single records and normalise representation
        - Fill AC/AF/AN if enabled
        - Drop non-variants (AF ==0) or variants with alt == '*' (GATK emits these)

        TODO: detect if fill-tags needs to be run and run it (saves time if missing)
    */

    input:
    tuple val(i), path(vcf)

    output:
    tuple val(i), path(output), path("${output}.tbi")

    script:
    output = vcf.name.replaceAll(/\.(vcf\.gz|vcf\.bgz|bcf)$/, '.clean.vcf.gz')
    // decrease VCF size by dropping unused fields
    remove = 'QUAL,FILTER' +
        (params.struc_info    ? ',^' + params.struc_info  .collect{ "INF/$it" }.join(',') : '') +
        (params.struc_format  ? ',^' + params.struc_format.collect{ "FMT/$it" }.join(',') : '')
    """
    bcftools view $vcf --no-version -Ou ${params.struc_vcf_filter ? "-f  '$params.struc_vcf_filter'": ''} \\
        -e "SVTYPE='BND'" \\
        | bcftools annotate --no-version -Ou --remove '$remove' \\
        ${params.struc_fill_tags ? '| bcftools +fill-tags --no-version -Ou -- -t AC,AF,AN' : ''} \\
        | bcftools view -e 'AF=0' --no-version -Oz -o $output --write-index=tbi
    """
    // Exclude BNDs for now as VEP annotation with BNDs present is buggy
    // - (other variants in proximity to BND are annotated with genes from other side/chrom of BND)
}