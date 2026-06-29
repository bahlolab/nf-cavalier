
process FILTER {
    label 'C2M16T2'
    label 'cavalier'
    publishDir "${params.outdir}/by_family/$fam", mode: 'copy', pattern: "*.csv*"
    publishDir "${params.outdir}/by_family/$fam", mode: 'copy', pattern: "*.png"
    tag "$fam"
    /*
        - Read TSV formatted variants for a given family
        - Identify candidate variants with R script 
        - Make outputs for visualisation tools
    */  

    input:
    tuple val(fam), path(short_var), path(struc_var), path(ped)
    path(gene_set)
    val(filter_opts)
    path(cav_opts)
    path(cache_dir)

    output:
    tuple val(fam), path("${fam}*.short.filtered_variants.rds") , emit: short_rds     , optional: true
    tuple val(fam), path("${fam}*.short.filtered_variants.csv") , emit: short_csv     , optional: true
    tuple val(fam), path("${fam}*.short.igv.bed")               , emit: short_igv     , optional: true
    tuple val(fam), path("${fam}*.short.count")                 , emit: short_count   , optional: true
    tuple val(fam), path("${fam}*.short.reason_filtered.csv.gz"), emit: short_reason  , optional: true
    tuple val(fam), path("${fam}*.short.filtering.png")         , emit: short_flt_png , optional: true
    tuple val(fam), path("${fam}*.short.filtering.rds")         , emit: short_flt_plot, optional: true

    tuple val(fam), path("${fam}*.struc.filtered_variants.rds") , emit: struc_rds     , optional: true
    tuple val(fam), path("${fam}*.struc.filtered_variants.csv") , emit: struc_csv     , optional: true
    tuple val(fam), path("${fam}*.struc.samplot.tsv")           , emit: struc_samplot , optional: true
    tuple val(fam), path("${fam}*.struc.lines.txt")             , emit: struc_lines   , optional: true
    tuple val(fam), path("${fam}*.struc.count")                 , emit: struc_count   , optional: true
    tuple val(fam), path("${fam}*.struc.reason_filtered.csv.gz"), emit: struc_reason  , optional: true
    tuple val(fam), path("${fam}*.struc.filtering.png")         , emit: struc_flt_png , optional: true
    tuple val(fam), path("${fam}*.struc.filtering.rds")         , emit: struc_flt_plot, optional: true
    
    script:
"""
cat > filter_options.json <<< '${filter_opts}'

filter.R $ped $gene_set filter_options.json \\
    ${short_var.size() > 0 ? "--short-var $short_var" : ""} \\
    ${struc_var.size() > 0 ? "--struc-var $struc_var" : ""} \\
    --output $fam \\
    --cav-opts $cav_opts
"""
}