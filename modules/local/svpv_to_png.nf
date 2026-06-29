
process SVPV_TO_PNG {
    label 'C2M2T2'
    label 'poppler'
    tag "$fam"

    input:
    tuple val(fam), path(pdfs)

    output:
    tuple val(fam), path("*.png")

    script:
    """
    printf "%s\\n" $pdfs | xargs -n 1 -P ${task.cpus} -I {} sh -c '
        NAME=\$(basename "{}" .pdf)
        pdftoppm -png -r 300 -singlefile "{}" "SVPV_\$NAME"
    '
    """
}