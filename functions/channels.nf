include { read_ped  } from './helpers'
include { read_alignments } from './helpers'
include { make_path } from './helpers'

// helper functions to create input channels for processes

def file_channel(filename) {
    Channel.value(file(filename, checkIfExists: true).toAbsolutePath())
}
// return various HTS files with extensions
def index_channel(filename, extension) {
    Channel.value(
        [
            file(filename, checkIfExists: true).toAbsolutePath(), 
            extension instanceof List ? 
                (extension.collect { ext -> 
                    file(filename + ".$ext", checkIfExists: true).toAbsolutePath()
                }) :
                file(filename + ".$extension", checkIfExists: true).toAbsolutePath()
        ]
    )
}

def tabix_channel(filename) {
    index_channel(filename, 'tbi')
}

def vcf_channel(filename) {
    Channel.value(
        [
            file(filename, checkIfExists: true).toAbsolutePath(),
            file("${filename}.tbi").exists() ?
                file("${filename}.tbi", checkIfExists: true).toAbsolutePath() :
                file("${filename}.csi", checkIfExists: true).toAbsolutePath() 
        ]
    )
}

def fasta_channel(filename) {
   index_channel(filename, 'fai')
}

def ref_fasta_channel() {
    fasta_channel(params.ref_fasta)
}

def func_source_channel() {
    def src_list = ["$projectDir/bin/snv_functions.R"] +
        (
            params.report_func_source ? 
            (params.report_func_source.split(',')) :
            []
        )

    Channel.value(
        src_list.collect { file(it, checkIfExists: true).toAbsolutePath() }
    )
}

def pedigree_channel(ped) {

    ped 
        .flatMap { read_ped(it) }
        .unique()
        .map { it.values() as ArrayList }
        .collectFile(newLine: true) {
            [ "${it[0]}.ped", it.join('\t')]
        }
        .map { [it.name.replaceAll('.ped', ''), it] }
    // fam, ped
}

def alignment_channel(alignments, ped) {
    alignments
        .splitCsv(sep: '\t')
        .map { 
            def alignment_file = file(it[1], checkIfExists: true).toAbsolutePath()
            // Check for .bai (BAM index) or .crai (CRAM index)
            def index_file = file(it[1] + '.bai').exists() ? 
                file(it[1] + '.bai', checkIfExists: true).toAbsolutePath() :
                file(it[1] + '.crai', checkIfExists: true).toAbsolutePath()
            [
                it[0],
                alignment_file,
                index_file
            ] 
        }
        .combine(ped.flatMap { read_ped(it) }.map { [it.iid, it.fid] }, by: 0)
        .map { it[[3,0,1,2]] }
        .groupTuple(by: 0) 
    // fam, [iid], [alignment], [index]
}

def cache_dir_channel() {
    if (params.cavalier_cache_dir) {
        Channel.value(make_path(params.cavalier_cache_dir))
    } else {
        throw new Exception("Please define params.cavalier_cache_dir")
    }
}

def somalier_channel() {
    Channel.value(
        [
            file("${params.somalier_dir}/sites.hg38.vcf.gz"      , checkIfExists: true).toAbsolutePath(),
            file("${params.somalier_dir}/ancestry-labels-1kg.tsv", checkIfExists: true).toAbsolutePath(),
            file("${params.somalier_dir}/1kg.somalier.tar.gz"    , checkIfExists: true).toAbsolutePath(),
        ]
    )
}





