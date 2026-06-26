
process SCATTER {
    label 'C4M4T2'
    label 'blocky'
    /*
        - Split VCF/BCF into pieces using its index
        - accepts bgzipped VCF or BCF (.tbi or .csi index)
        - blocky does not convert format, so shards keep the input suffix
    */
    input:
    tuple path(vcf), path(index)
    val(n_shards)
    val(check)

    output:
    path("${prefix}*")

    script:
    suffix = (vcf.name =~ /\.(vcf\.gz|vcf\.bgz|bcf)$/)[0][1]
    prefix = vcf.name.replaceAll(/\.(vcf\.gz|vcf\.bgz|bcf)$/, '') + '.shard'
    if (n_shards > 1)
    """
    blocky scatter $vcf --n-shards $n_shards --clamp --output $prefix.{}.$suffix
    """
    else
    """
    ln -s $vcf ${prefix}.1.$suffix
    """

}