
process IGV_REPORT {
    label 'C4M4T2'
    label 'igvreports'
    tag "$fam"
    publishDir "${params.outdir}/by_family/$fam", mode: 'copy', pattern: '*.igv_report.html'
    /*
        - Generate html igv-reports for candidate variants identified by cavalier
        - Firstly for all samples combined with VCF 
        - Secondly individually to extract PNGs to put into slides
    */

    input:
    tuple val(fam), val(sites), path(vcf), path(tbi), val(ids), path(bams), path(bais) // bams can be BAM or CRAM, bais can be .bai or .crai
    tuple path(ref), path(ref_fai)
    path igv_report_mod

    output:
    tuple val(fam), path("${fam}.igv_report.html")  , emit: combined
    tuple val(fam), path("${fam}.igv_report.*.html"), emit: individual

    script:
    // paralellise cmds with xargs
    def cmds = [
        "create_report sites.bed --genome hg38 --flanking 250 --fasta $ref --tracks ${fam}.vcf.gz ${bams.join(' ')} --output ${fam}.igv_report.html"
    ] +
    [ids, bams].transpose().collect{ id, bam ->
        "create_report sites.bed --genome hg38 --standalone --flanking 100 --fasta $ref --tracks $bam --output ${fam}.igv_report.${id}.html"
    }
"""
ln -s $vcf ${fam}.vcf.gz
ln -s $tbi ${fam}.vcf.gz.tbi

cat > sites.bed <<< '${sites}'

cat > cmds <<< '${cmds.join('\n')}'

cat cmds | xargs -I {} -P $task.cpus /bin/bash -c "{}"

sed -i "/<head>/r $igv_report_mod" "${fam}.igv_report.html"
sed -i 's/const tableJson/var tableJson/; s/const sessionDictionary/var sessionDictionary/' "${fam}.igv_report.html"
"""
}
