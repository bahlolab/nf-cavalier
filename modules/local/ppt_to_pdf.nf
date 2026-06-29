
process PPT_TO_PDF {
    container 'linuxserver/libreoffice:7.6.7'
    label 'C2M4T4'
    maxRetries 3
    errorStrategy 'retry'
    tag { "$fam" }
    publishDir "${params.outdir}/by_family/$fam", mode: 'copy'
    /*
        - Convert powerpoints to PDFs
        - Error set to ignore because sometimes randomly fails
    */

    input:
    tuple val(fam), path(pptx)

    output:
    tuple val(fam), path("*.pdf")

    script:
    """
    HOME=\$PWD soffice --headless --convert-to pdf $pptx || echo 'done'
    """
}