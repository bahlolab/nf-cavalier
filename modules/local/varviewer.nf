

process VARVIEWER {
    label 'C2M16T2'
    container null
    publishDir "${params.outdir}", mode: 'copy'


    input:
    val done
    path rmd
    path output_dir

    output:
    path "variant_viewer.html"

    script:
    """
    workdir=\$(pwd)
    cd ${output_dir}
    Rscript -e "rmarkdown::render('\${workdir}/${rmd}', output_file='\${workdir}/variant_viewer.html', knit_root_dir=getwd())"
    """
}