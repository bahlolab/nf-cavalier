#!/usr/bin/env nextflow

include { SETUP_REFS } from './workflows/main'
include { validate_setup_params } from './functions/setup_helpers'

workflow {
    validate_setup_params()
    SETUP_REFS()
}
