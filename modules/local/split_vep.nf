
process SPLIT_VEP {
    label 'C2M2T2'
    label 'bcftools'
    tag "$fam:$set"
    /*
        - Restrict VCF to select samples
        - Filter for only variants carried by an affected individual
        - Create TSV output in addition to VCF for simpler parsing in R using bcftools +split-vep
    */

    input:
    tuple val(set), path(vcf), path(index), val(inf), val(fmt), val(fam), val(aff), val(unaff)
    val(check)

    output:
    tuple val(set), val(fam), path(out_vcf), path("${out_vcf}.tbi"), emit: vcf
    tuple val(set), val(fam), path(out_tsv)                        , emit: tsv

    script:
    out_vcf = vcf.name.replaceAll(/(\.vcf\.gz)|(\.bcf)/, ".family_${fam}.vcf.gz")
    out_tsv = vcf.name.replaceAll(/(\.vcf\.gz)|(\.bcf)/, ".family_${fam}.tsv.gz")
    // extract INFO fields from VCF
    def inf_hdr = inf.join('\\t')
    def inf_qry = inf.collect {"%$it"}.join('\\t')
    // extract sample FORMAT fields from VCF
    def samples = (aff + unaff).unique().sort()
    def fmt_hdr = fmt
        .collect { FMT -> samples.collect { SAM -> "FMT_${FMT}_${SAM}" } }
        .flatten()
        .join('\t')
    def fmt_query = fmt.collect{"[%$it\\t]"}.join('')

    """
    printf "${aff.join('\\n')}\\n" > aff

    bcftools view --threads ${task.cpus} --no-version --no-update $vcf -s ${samples.join(',')} -Ou \\
        | bcftools view --no-version --threads ${task.cpus} -i "GT[@aff]='alt'" --write-index=tbi -Oz -o $out_vcf

    VEP_HDR=\$( bcftools +split-vep $vcf -l | cut -f2- | paste -sd '\\t' - )
    (
        echo -e "LINE_ID\\tCHROM\\tPOS\\tREF\\tALT\\t${inf_hdr}\\t${fmt_hdr}\\t\${VEP_HDR}"
        bcftools view ${out_vcf} \\
        | awk 'BEGIN{OFS="\\t"; i=0} /^#/ {print; next} {i++; \$3=i; print}' \\
        | bcftools +split-vep - -d -A tab \\
            -f '%ID\\t%CHROM\\t%POS\\t%REF\\t%ALT\\t${inf_qry}\\t${fmt_query}%CSQ\\n' \\
    ) | bgzip > $out_tsv
    """
}