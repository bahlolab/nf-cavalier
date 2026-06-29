
process VCFANNO {
    label 'C2M2T2'
    label 'bcftools'
    tag "$i"
    /*
        - Run specified VCFanno annotations
        - optionally filter output
    */ 

    input:
        tuple val(i), path(in_vcf), path(idx)
        val(conf)
        path(ann_files)
        path(vcfanno)

    output:
        tuple val(i), path(output)

    script:
    output  = in_vcf.name.replace('.vcf.gz', ".vcfanno.vcf.gz")
    filter = params.short_vcfanno_filter ? "-i '$params.short_vcfanno_filter'" : ''

"""
cat > vcfanno.conf  <<< '${conf}'

[ -x "$vcfanno" ] || chmod +x "$vcfanno"

./$vcfanno -p ${task.cpus} vcfanno.conf $in_vcf \\
    | bcftools view --no-version --threads ${task.cpus} $filter -Oz -o $output
"""
}
