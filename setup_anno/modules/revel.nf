
// Download REVEL v1.3 raw zip, reformat for VEP, filter to GRCh38 positions.
// Recipe from VEP REVEL.pm release/113.
process REVEL {
    label 'C2M16T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/revel" }

    input:
    val url

    output:
    tuple path('revel_1.3.hg38.vep.tsv.gz'), path('revel_1.3.hg38.vep.tsv.gz.tbi')

    script:
    """
    wget --tries=5 -q -O revel.zip '${url}'
    unzip -p revel.zip revel_with_transcript_ids \\
        | tr ',' '\\t' \\
        | awk 'NR==1{print "#"\$0; next} \$3!="."' \\
        > filtered.tsv
    rm revel.zip

    { head -n1 filtered.tsv; tail -n+2 filtered.tsv | sort -k1,1 -k3,3n; } \\
        | bgzip -c > revel_1.3.hg38.vep.tsv.gz
    rm filtered.tsv
    tabix -f -s 1 -b 3 -e 3 revel_1.3.hg38.vep.tsv.gz
    """
}
