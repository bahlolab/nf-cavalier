
// Build a tabix .tbi index next to a previously-downloaded file.
// storeDir matches FETCH's so the .tbi co-locates with its primary; on rerun
// the named output (.tbi) is detected in storeDir and the process skips.
process TABIX {
    label 'C2M2T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/${subdir}" }
    tag      { src.name }

    input:
    tuple val(subdir), path(src), val(tabix_args)

    output:
    path "${src.name}.tbi"

    script:
    """
    tabix -f ${tabix_args} '${src.name}'
    """
}
