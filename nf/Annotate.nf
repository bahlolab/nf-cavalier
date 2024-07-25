include { path; ref_data_channel; pop_sv_channel } from './functions'
include { vep; vep_sv } from './vep'
include { vcf_concat as vcf_concat_1 } from './vcf_concat'
include { vcf_concat as vcf_concat_sv } from './vcf_concat' addParams(allow_overlap: true)
include { ConcatVCF as ConcatPopVCF } from './ConcatVCF' addParams(id: 'PopSV')
include { SplitSVs as SplitPopSVs } from './SplitSVs'

workflow Annotate {
    take:
        vcf_chunks // // set, i, j, vcf, index

    main:
    ref_data = ref_data_channel() | map { it[[0, 1, 3]] } // ref_fa, ref_fai, vep_cache

    // SNP/Indel VCFs
    if (params.snp_vcf) {
        snp_ann = vcf_chunks |
            filter { it[0] == 'SNP' } |
            map { it[0..3] } |
            combine(ref_data) |
            vep
    } else {
        snp_ann = Channel.fromList([])
    }

    // SV VCFs
    if (params.sv_vcf) {

        sv_type_match_rev = params.sv_type_match
            .collectMany { k, v -> v.collect { [it, k] }}
            .groupBy { it[0] }
            .collectEntries { k, v -> [(k) : v.collect{ it[1] }.unique()] }

        pop_sv_split = pop_sv_channel() |
            map { ['SV'] + it } |
            SplitPopSVs |
            filter { sv_type_match_rev.keySet().contains(it[0]) } |
            flatMap { sv_type_match_rev[it[0]].collect {type -> [type] + it[1..2] } } |
            ConcatPopVCF |
            mix(vcf_stub(pop_sv_channel()) | map { ['STUB'] + it })

        sv_ann = vcf_chunks |
            filter { it[0] != 'SNP' } |
            map { it[0..3] } |
            map { (params.sv_type_match.keySet().contains(it[0]) ? [it[0]] : ['STUB']) + it } |
            combine(pop_sv_split, by:0) |
            map { it.drop(1) } |
            combine(ref_data) |
            vep_sv
    } else {
        sv_ann = Channel.fromList([])
    }

    ann_vcfs = snp_ann |
        mix(sv_ann) |
        collectFile(newLine: true, sort: { new File(it).toPath().fileName.toString() }) {
            ["${it[0]}.files.txt", it[1].toString()]
        } |
        map { [(it.name =~ /([^.]+)\.files\.txt/)[0][1]] + [it] } |
        vcf_concat_1 |
        branch { snp: it[0] == 'SNP'; sv: true }

    output = ann_vcfs.sv |
        collectFile(newLine: true, sort: { new File(it).toPath().fileName.toString() }) {
            ["SV.files.txt", it[1].toString()]
        } |
        map { ['SV', it] } |
        vcf_concat_sv |
        mix(ann_vcfs.snp)

    emit: output // set, vcf, index
}

process vcf_stub {
    cpus 1
    memory '2 GB'
    time '1 h'
    // publishDir "progress/vcf_stub", mode: 'symlink'

    input:
    tuple path(vcf), path(index)

    output:
    tuple path(stub), path("${stub}.tbi")

    script:
    stub = vcf.name.replaceAll(/(\.vcf\.gz)|(\.bcf)$/, '.stub.vcf.gz')
    """
    bcftools view --no-version -h $vcf | 
        bcftools view --no-version -Oz -o $stub
    bcftools index -t $stub
    """
}
