
process GATHER {
    label 'C10M10T2'
    label 'bcftools'
    publishDir "${params.outdir}", mode: 'copy'
    /*
        - Gather scattered annotated VCF filters
        - Convert to BCF for faster queries downstream
    */

    input:
    path(vcfs)

    output:
    tuple path(output), path("${output}.csi")

    script:
    output = vcfs[0].name.replaceAll('shard\\.\\d+\\.', '').replaceAll('\\.vcf\\.gz$', '.bcf')
    """
    ls *.vcf.gz | xargs -n1 -P$task.cpus -I{} sh -c 'bcftools view {} -Ob -o {}.bcf'
    bcftools concat *.bcf --threads $task.cpus --write-index -Ob -o $output
    rm *.vcf.gz.bcf
    """
}