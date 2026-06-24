
// UCSC ncbiRefSeqSelect.txt.gz -> ncbiRefSeqSelect.<YYYY-MM>.tsv
// Date stamp comes from the HTTP Last-Modified header.
process REF_GENE {
    label 'C2M2T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/ref_gene" }

    input:
    val url

    output:
    path 'ncbiRefSeqSelect.*.tsv'

    script:
    """
    YM=\$(date +%Y-%m)
    wget --tries=5 -q -O - '${url}' | gunzip -c > "ncbiRefSeqSelect.\${YM}.tsv"
    """
}
