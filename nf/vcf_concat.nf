
params.allow_overlap = false


process vcf_concat {
    label 'C2M2T2'
    publishDir "${params.outdir}/vcf_concat", mode: 'copy'
    tag { "$set" }

    input:
    tuple val(set), path(file_list)

    output:
    tuple val(set), path(out_vcf), path("${out_vcf}.csi")

    script:
    out_vcf = "${set}.bcf"
    """
    bcftools concat ${params.allow_overlap ? '--allow-overlaps' : '--naive-force' } \\
        --file-list $file_list -Ob -o $out_vcf
    bcftools index --threads 2 $out_vcf
    """
}
