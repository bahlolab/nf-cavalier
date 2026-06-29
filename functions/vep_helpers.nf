
include { file_channel  } from './channels'
include { tabix_channel } from './channels'

def spliceai_enabled() {
    (params.vep_spliceai_snv   ? true : false) && 
    (params.vep_spliceai_indel ? true : false)
}

def get_spliceai_files() {
    def snv
    def indel
    if (spliceai_enabled()) {
        snv   = tabix_channel(params.vep_spliceai_snv)
        indel = tabix_channel(params.vep_spliceai_indel)
    } else {
        snv   = tabix_channel("$projectDir/misc/dummy/spliceai_snv")
        indel = tabix_channel("$projectDir/misc/dummy/spliceai_indel")
    }
    snv.concat(indel).collect()
}

def alphamiss_enabled() {
    params.vep_alphamissense ? true : false
}

def get_alphamiss_files() {
    if (alphamiss_enabled()) {
        return tabix_channel(params.vep_alphamissense)
    }
    return tabix_channel("$projectDir/misc/dummy/alphamissense")
}

def revel_enabled() {
    params.vep_revel ? true : false
}

def get_revel_files() {
    if (revel_enabled()) {
        return tabix_channel(params.vep_revel)
    }
    return tabix_channel("$projectDir/misc/dummy/revel")
}

def utr_ann_enabled() {
    params.vep_utr_annotator ? true : false
}

def get_utr_ann_files() {
    if (utr_ann_enabled()) {
        return file_channel(params.vep_utr_annotator)
    }
    return file_channel("$projectDir/misc/dummy/utr_annotator")
}

def get_vep_fields(SHORT = true) {
    // TODO: 'MANE', 'MANE_SELECT', 'MANE_PLUS_CLINICAL', 'CCDS' seem to be empty - Why? also maybe drop anyway
    def vep_fields = [
          'SYMBOL', 'Gene', 'VARIANT_CLASS', 'Consequence', 'IMPACT', 'Feature_type', 'Feature',
          'BIOTYPE', 'EXON', 'INTRON', 'HGVSc', 'HGVSp', 'HGVSg', 'Amino_acids',
          'HGNC_ID', 'MANE', 'MANE_SELECT', 'MANE_PLUS_CLINICAL', 'CCDS', 'ENSP',
          'Existing_variation'
        ]

    if (SHORT) {
        vep_fields = vep_fields +
            ['SIFT', 'PolyPhen'] +
            (alphamiss_enabled() ? ['am_class', 'am_pathogenicity'] : [] ) +
            (revel_enabled() ? ['REVEL'] : [] ) +
            (spliceai_enabled() ? [
                'SpliceAI_pred_DP_AG', 'SpliceAI_pred_DP_AL', 'SpliceAI_pred_DP_DG', 'SpliceAI_pred_DP_DL', 
                'SpliceAI_pred_DS_AG', 'SpliceAI_pred_DS_AL', 'SpliceAI_pred_DS_DG', 'SpliceAI_pred_DS_DL', 
                'SpliceAI_pred_SYMBOL'] :
                []
            ) +
            (utr_ann_enabled() ? [
                '5UTR_annotation', '5UTR_consequence', 'Existing_InFrame_oORFs', 'Existing_OutOfFrame_oORFs',
                'Existing_uORFs' ] : 
                []
            )
    }
    
    return vep_fields
}

def get_vep_cache() {
    file_channel(params.vep_cache)
}

def get_svafdb() {
    file_channel(params.svafdb)
}


