
process STORE {
    label 'C2M2T2'
    tag "$id"
    storeDir "${params.cavalier_cache_dir}/store"
    executor 'local'
    maxForks 10
    
    /*
        - Place a copy in storeDir to avoid breaking downstream cache
    */

    input: 
    tuple val(id), path(name)
    
    output: 
    path(name)

    script:
    """
    cp $name tmp && mv tmp $name
    """
}