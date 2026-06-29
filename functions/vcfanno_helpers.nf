def get_vcfanno_map() {
    [
        [   vcf: params.vcfanno_gnomad, 
            fields: [gnomad_AF: 'AF', gnomad_AC: 'AC', gnomad_FAF95: 'fafmax_faf95_max', gnomad_nhomalt: 'nhomalt']
        ],
        [   tsv: params.vcfanno_cadd_snv,
            fields: [CADD: 6]
        ],
        [   tsv: params.vcfanno_cadd_indel,
            fields: [CADD: 6]
        ],
        [   vcf: params.vcfanno_clinvar ,
            fields: [CLNSIG: 'CLNSIG', CLNGENE: 'GENEINFO',  CLNVID: 'ID']
        ]
    ] + (params.vcfanno_custom ?: [])
}

def get_vcfanno_conf() {
    Channel
        .fromList(get_vcfanno_map())
        .map { ann ->
            // choose file key and toml keyword
            def file   = file(ann.vcf ?: ann.tsv).name
            def is_vcf = ann.containsKey('vcf')
            def key    = is_vcf ? 'fields' : 'columns'
            def op     = ann.op ?: 'self'
            // build the three arrays
            def values = ann.fields.values().collect { it instanceof String ? "\"${it}\"" : "${it}" }.join(', ')
            def names  = ann.fields.keySet().collect { "\"$it\"" }.join(', ')
            def ops    = ann.fields.collect { "\"$op\"" }.join(', ')
            // one TOML block per annotation
            def block =  
                "[[annotation]]\n" +
                "file    = \"${file}\"\n" +
                "${key}  = [${values}]\n" +
                "names   = [${names}]\n" +
                "ops     = [${ops}]"
            // println block
            return block
        }
        .collect()
        .map { it.join('\n') }
}

def get_vcfanno_files() {
    Channel
        .fromList(get_vcfanno_map())
        .flatMap { 
            [
                file(it.vcf ?: it.tsv, checkIfExists: true).toAbsolutePath(),
                file("${it.vcf ?: it.tsv}.csi").exists() ?
                    file("${it.vcf ?: it.tsv}.csi", checkIfExists: true).toAbsolutePath() :
                    file("${it.vcf ?: it.tsv}.tbi", checkIfExists: true).toAbsolutePath() 
            ]
        }
        .toSortedList()
}
