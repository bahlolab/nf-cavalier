
// Discovers the latest dated ClinVar weekly VCF in the NCBI directory listing
// (e.g. clinvar_20260615.vcf.gz) and downloads it + its .tbi.
process CLINVAR {
    label 'C2M2T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/clinvar" }

    input:
    val url_dir   // e.g. 'https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/'

    output:
    tuple path('clinvar_*.vcf.gz'), path('clinvar_*.vcf.gz.tbi')

    script:
    def base = url_dir.endsWith('/') ? url_dir : "${url_dir}/"
    """
    LATEST=\$(wget -q -O - '${base}' \\
        | grep -oE 'clinvar_[0-9]{8}\\.vcf\\.gz' \\
        | sort -u | sort -t_ -k2,2n | tail -n1)
    if [ -z "\$LATEST" ]; then
        echo "ERROR: no clinvar_<YYYYMMDD>.vcf.gz file found at ${base}" >&2
        exit 1
    fi
    wget --tries=5 -q -O "\$LATEST"      "${base}\${LATEST}"
    wget --tries=5 -q -O "\${LATEST}.tbi" "${base}\${LATEST}.tbi"
    """
}
