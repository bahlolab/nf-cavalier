
process SOMALIER {
    label 'C2M4T2'
    container 'quay.io/biocontainers/somalier:0.3.1--hc78c8e0_0'
    publishDir "${params.outdir}/qc/", mode: 'copy'

    /*
        - Extract somalier sites from input VCF
        - Run somalier relate to check sample relatedness
        - Run somalier ancestry to infer sample ancestry using 1KG reference
    */

    input:
    val(check)
    tuple path(vcf), path(tbi)
    path (ped)
    tuple path(fasta), path(fai)
    tuple path(sites), path(ancestry_labels), path(kg_somalier)

    output:
    tuple path("somalier.pairs.tsv"),
          path("somalier.samples.tsv"),
          path("somalier-ancestry.tsv"),
          path("somalier.html"),
          path("somalier-ancestry.html")

    script:
    """
    somalier extract \\
        --sites $sites \\
        --fasta $fasta \\
        --out-dir extracted/ \\
        $vcf

    somalier relate extracted/*.somalier ${ped ? "--ped $ped" : ''}

    tar zxf $kg_somalier

    somalier ancestry \\
        --labels $ancestry_labels \\
        1kg-somalier/*.somalier ++ \\
        extracted/*.somalier

    mv somalier-ancestry.somalier-ancestry.html somalier-ancestry.html
    mv somalier-ancestry.somalier-ancestry.tsv somalier-ancestry.tsv
    
    patch_somalier_ancestry.sh somalier-ancestry.html -o tmp.html && mv tmp.html somalier-ancestry.html
    """
}
