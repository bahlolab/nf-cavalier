
process PDF_UNITE {
    label 'C2M2T2'
    label 'poppler'
    tag "$gene"
    publishDir "${params.outdir}/by_gene", mode: 'copy'

    input:
    tuple val(gene), path(pdfs)

    output:
    path("${gene}.pdf")

    script:
    """
    pdfunite *.pdf ${gene}.pdf
    """
}