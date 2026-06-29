
process FETCH {
    label 'C2M2T24'
    label 'bcftools'
    storeDir { "${params.resource_dir}/${subdir}" }
    tag      { out_name }

    input:
    tuple val(subdir), val(url), val(out_name)

    output:
    path out_name

    script:
    """
    wget --tries=5 -nv -O '${out_name}' '${url}'
    """
}
