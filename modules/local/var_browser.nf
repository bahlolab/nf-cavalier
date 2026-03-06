

process VAR_BROWSER {
    label 'C2M2T2'
    container null
    publishDir "${params.outdir}", mode: 'copy'


    input:
    path rmd
    path short_cand
    path struc_cand
    path slides
    path igv_report
    path svpv
    path samplot


    output:
    path "variant_browser.html"

    script:
    """
    Rscript -e "rmarkdown::render('$rmd')"
    """
}