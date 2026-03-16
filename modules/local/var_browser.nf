

process VAR_BROWSER {
    label 'C2M2T2'
    container null
    publishDir "${params.outdir}",      mode: 'copy', pattern: "variant_browser.html"
    publishDir "${params.outdir}/qc",   mode: 'copy', pattern: "*-tbl.html"


    input:
    path browser_rmd
    path table_rmd
    path short_cand
    path struc_cand
    path slides
    path igv_report
    path svpv
    path samplot
    tuple path(pairs), path(samples), path(ancestry), path(somalier_html), path(ancestry_html)
    path(params_json)
    path(versions)
    path(gene_set)
    
    output:
    path "variant_browser.html"
    path "*-tbl.html", optional: true

    script:
    if (pairs)
    """
    Rscript -e "rmarkdown::render('$table_rmd', params=list(input='$pairs'   , prefix='somalier-pairs')   , output_file='somalier-pairs-tbl.html')"
    Rscript -e "rmarkdown::render('$table_rmd', params=list(input='$samples' , prefix='somalier-samples') , output_file='somalier-samples-tbl.html')"
    Rscript -e "rmarkdown::render('$table_rmd', params=list(input='$ancestry', prefix='somalier-ancestry'), output_file='somalier-ancestry-tbl.html')"
    Rscript -e "rmarkdown::render('$browser_rmd')"
    """
    else
    """
    Rscript -e "rmarkdown::render('$browser_rmd')"
    """
}