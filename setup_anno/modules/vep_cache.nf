
process VEP_CACHE {
    label 'C2M4T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/vep_cache" }

    input:
    val url

    output:
    path "homo_sapiens/${params.vep_cache_ver}_GRCh38"

    script:
    """
    wget --tries=5 -q -O cache.tar.gz '${url}'
    tar -xzf cache.tar.gz
    rm cache.tar.gz
    """
}
