
// Per-chromosome download + INFO strip
process GNOMAD_CHR {
    label 'C2M4T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/gnomad/per_chr" }
    tag "chr$chr"
    maxForks 8

    input:
    tuple val(url_pattern), val(chr)

    output:
    tuple path("gnomad.joint.v4.1.sites.chr${chr}.slim.vcf.gz"),
          path("gnomad.joint.v4.1.sites.chr${chr}.slim.vcf.gz.tbi")

    script:
    def url = url_pattern.replaceAll('<CHR>', chr.toString())
    def out = "gnomad.joint.v4.1.sites.chr${chr}.slim.vcf.gz"
    """
    printf 'INFO/AC_joint AC\\nINFO/AF_joint AF\\nINFO/fafmax_faf95_max_joint fafmax_faf95_max\\nINFO/nhomalt_joint nhomalt' > rename.txt
    bcftools view --threads $task.cpus -Ou '${url}' \\
        | bcftools annotate --threads $task.cpus -Oz \\
              -x '^INFO/AC_joint,INFO/AF_joint,INFO/fafmax_faf95_max_joint,INFO/nhomalt_joint' \\
              --rename-annots rename.txt \\
              --write-index=tbi \\
              -o '${out}'
    """
}

// Concat per-chromosome slim VCFs into one joint sites file.
process GNOMAD_CONCAT {
    label 'C2M4T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/gnomad" }

    input:
    path slim_vcfs, stageAs: 'in/*'

    output:
    tuple path('joint_sites_4.1.vcf.gz'), path('joint_sites_4.1.vcf.gz.tbi')

    script:
    """
    ls in/*.vcf.gz | sort -V > files.txt
    bcftools concat --threads $task.cpus -Oz -f files.txt -o joint_sites_4.1.vcf.gz --write-index=tbi

    # sanity check the index: random query against chr1:100000 must return exactly one record
    N=\$(bcftools view -H joint_sites_4.1.vcf.gz chr1:100000 | wc -l)
    if [ "\$N" -ne 1 ]; then
        echo "ERROR: tbi sanity check failed — bcftools view -H joint_sites_4.1.vcf.gz chr1:100000 returned \$N lines (expected 1)" >&2
        exit 1
    fi
    """
}

workflow GNOMAD {
    take:
    url_pattern
    chrs

    main:
    GNOMAD_CHR(
        chrs.map { chr -> tuple(url_pattern, chr) }
    )
    GNOMAD_CONCAT(
        GNOMAD_CHR.out.map { it[0] }.collect()
    )

    emit:
    GNOMAD_CONCAT.out
}
