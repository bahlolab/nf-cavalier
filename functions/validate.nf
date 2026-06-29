
def vcf_is_set() {
    if (params.short_vcf) {
        return(true)
    }
    if (params.struc_vcf) {
        return(true)
    }
    if (params.short_vcf_annotated) {
        return(true)
    }
    if (params.struc_vcf_annotated) {
        return(true)
    }
    return(false)
}

def validate_params() {
    
    if (!vcf_is_set()){
        throw new Exception("ERROR: Must specify at least one of 'params.short_vcf' or 'params.struc_vcf'")
    }

    if (!params.alignments) {
        throw new Exception("ERROR: Must specify 'params.alignments'")
    }

    if (!params.lists) {
        throw new Exception("ERROR: Must specify 'params.lists'")
    }

    if (!params.ped) {
        log.info("INFO: params.ped not defined, generating uninformative pedigree\n")
    }

    /*
        TODO: more validation of params
    */
}

