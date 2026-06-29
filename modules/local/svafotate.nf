
process SVAFOTATE {
    label 'C2M8T2'
    label 'svafotate'
    tag "$i"


    input: 
    tuple val(i), path(in_vcf), path(idx)
    path(svafdb)

    output:
    tuple val(i), path(output)


    script:
    output  = in_vcf.name.replace('.vcf.gz', ".svafotate.vcf.gz")
    """
    # restrict to gnomAD and relevant chromosomes (avoid running our of RAM)
    awk 'BEGIN{FS=OFS="\t"} NR==FNR {keep[\$1]; next} /^#/ || /^track/ {print; next} (\$1 in keep)' \\
        <(zcat $in_vcf | grep -v '^#' | cut -f1 | uniq | sed 's/^chr//') \\
        <(zcat $svafdb | awk 'NR==1 || /gnomAD/') \\
        | gzip > svafdb.filt.bed.gz
    
    svafotate annotate \\
        -v $in_vcf \\
        --cpu $task.cpus \\
        -f 0.9 \\
        -b svafdb.filt.bed.gz \\
        -O vcfgz \\
        -s gnomAD \\
        -o $output
    """
}