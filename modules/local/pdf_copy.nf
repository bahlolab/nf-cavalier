
process PDF_COPY {
    label 'C2M2T2'
    container null
    executor 'local'
    maxForks 10
    tag "$gene"
    publishDir "${params.outdir}/by_gene", mode: 'copy'

    input:
    tuple val(gene), path(pdf)

    output:
    path("${gene}.pdf")

    script:
    """
    ln -s $pdf ${gene}.pdf
    """
}