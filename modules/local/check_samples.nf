
process CHECK_SAMPLES {
    label 'C2M2T2'
    label 'cavalier'

    input:
    path(alignments)
    path(ped)
    path(short_samples)
    path(struc_samples)

    output:
    val  true                , emit: check
    path 'intersect_alignments.tsv', emit: alignments
    path 'intersect.ped'     , emit: ped
    path 'warnings.txt'      , emit: warnings
    
    script:
    """
    check_samples.R \\
        ${short_samples.size() == 0 ? 'UNSET' : short_samples} \\
        ${struc_samples.size() == 0 ? 'UNSET' : struc_samples} \\
        $alignments \\
        intersect_alignments.tsv \\
        ${ped.size() == 0 ? 'UNSET' : ped} \\
        intersect.ped
        
    touch warnings.txt
    """
}

