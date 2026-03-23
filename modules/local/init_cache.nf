
process INIT_CACHE {
    label 'C2M2T2'
    label 'cavalier'
    tag "$date_ymd"
    publishDir "${params.outdir}", mode: 'copy', pattern: 'cavalier_options.*.json'
    
    /*
        - Initialise cavalier cache, checking for latest version of HGNC, HPO, MI_OMIM
    */

    input: 
    val(date_ymd)
    val(cav_opts)
    path(cache_dir)
    path(local_lists)
    val(external_lists)

    output: 
    path('cavalier_options.*.json'), emit: options
    path('output/*')               , emit: genes
    path('versions.tsv')           , emit: versions

    script:
    def lists = ""
    if (local_lists[0].name != 'local_list') {
        lists = "${local_lists.join(',')}"
    }
    if (external_lists) {
        lists = "$lists${lists ? ',': ''}${external_lists.join(',')}"
    }

"""
cat > cavalier_options.json <<< '${cav_opts}'

init_cache.R cavalier_options.json $lists
"""
}