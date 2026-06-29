include { get_vcfanno_map  } from './vcfanno_helpers.nf'

Path path(filename) {
    file(filename, checkIfExists: true).toAbsolutePath()
}

Path make_path(filename) {
    if (! new File(filename).isDirectory()) {
        new File(filename).mkdir()
    }
    path(filename)
}

ArrayList<Map> read_tsv(Path path, List<String> names ) {
    path.toFile().readLines().with { lines ->
        lines.each { assert it.split('\t').size() == names.size() }
        lines.collect {
            [names, it.split('\t')].transpose().collectEntries { k, v -> [(k): v] }
        }
    }
}

ArrayList<Map> read_csv(Path path, List<String> names ) {
    path.toFile().readLines().with { lines ->
        lines.each {assert it.split(',').size() == names.size() }
        lines.collect {
            [names, it.split(',')].transpose().collectEntries { k, v -> [(k): v] }
        }
    }
}
/* read_csv but with flexible column names and ordering */
ArrayList<Map> read_csv2(Path path, List<String> req_names, List<String> opt_names ) {
    path.toFile().readLines().with { lines ->
        def names = lines[0].split(',') as ArrayList<String>
        assert req_names.all { names.contains(it) }
        // TODO - check opt_names
        lines.each {assert it.split(',').size() == names.size() }
        lines.collect {
            [names, it.split(',')].transpose().collectEntries { k, v -> [(k): v] }
        }
    }
}

String date_ymd() {
    def date = new Date()
    def sdf = new java.text.SimpleDateFormat("yyyy-MM-dd")
    sdf.format(date)
}

def read_ped(input) {

    def ped = read_tsv(input, ['fid', 'iid', 'pid', 'mid', 'sex', 'phe'])
    def ped_families = ped.collect { it.fid }.unique()
    
    def fam_w_aff = ped
        .groupBy { it.fid }
        .collect { k, v -> [
            k, v.findAll {it.phe == '2'}.collect {it.iid} ] 
        }
        .findAll { it[1].size() > 0 }
        .collect { it[0] }

    if (fam_w_aff.size() == 0) {
        throw new Exception("No affected individuals in pedigree")
    }
    
    def fam_wo_aff = ped_families - fam_w_aff
    
    if (fam_wo_aff.size() > 0) {
        def n = fam_wo_aff.size()
        def fams =  n > 5 ? fam_wo_aff[0..4] + ['...'] : fam_wo_aff
        log.warn("$n famil${n > 1 ? 'ies':'y'} with no affected members will be excluded: ${fams.join(', ')}")
    }

    ped.findAll { fam_w_aff.contains(it.fid) }
}

def get_external_lists() {
    def lists_list = params.lists.split(',') as ArrayList
    def reg1 = /^(HP|PA[A-Z]+|HGNC|G4E|chr):.*/
    def reg2 = /^[^:]+:[0-9]+-[0-9]+$/
    lists_list.findAll { it ==~ reg1 ||  it ==~ reg2 }
}

def get_local_lists() {
    def lists_list = params.lists.split(',') as ArrayList
    def reg1 = /^(HP|PA[A-Z]+|HGNC|G4E|chr):.*/
    def reg2 = /^[^:]+:[0-9]+-[0-9]+$/
    def loc = lists_list.findAll { !(it ==~ reg1) }.findAll { !(it ==~ reg2) }
    if (loc) {
        Channel.value(loc.collect { path(it) })
    } else {
        Channel.value(path("$projectDir/misc/dummy/local_list"))
    }
}


def get_fam_aff_un(pedigree_channel, bam_channel) {

    pedigree_channel
        .splitCsv(sep: '\t')
        .map { [ it[0], it[1][1], it[1][5] == '2'] } // fam_id, sam_id, is_affected
        .combine(bam_channel.flatMap { x -> x[1].collect { [x[0], it]} }, by: [0,1])
        .groupTuple(by:0)
        .map { 
            [
                it[0],
                [it[1], it[2]].transpose().findAll{ it[1] }.collect {it[0]},
                [it[1], it[2]].transpose().findAll{ !it[1] }.collect {it[0]}
            ] 
        } // fam, [aff], [un]
}

def get_cavalier_opts() {
    def cav_opts = (params.cavalier_options ?: [:]) + [cache_dir: params.cavalier_cache_dir]
    groovy.json.JsonOutput.prettyPrint(
          groovy.json.JsonOutput.toJson(cav_opts)
    )
}

def get_filter_opts() {
    def filter_opts = params.findAll { k, v -> k.startsWith('FILTER_') && v != null }
    groovy.json.JsonOutput.prettyPrint(
          groovy.json.JsonOutput.toJson(filter_opts)
    )
}

def get_slide_info() {
    def info = [
        SHORT: params.SLIDE_INFO_SHORT,
        STRUC: params.SLIDE_INFO_STRUC
    ]
    groovy.json.JsonOutput.prettyPrint(
          groovy.json.JsonOutput.toJson(info)
    )
}

def collect_csv(csv_channel, filename) {
    
    csv_channel
        .first()
        .splitText(limit:1)
        .map {it.trim() }
        .concat(
            csv_channel
                .toSortedList { it.name }
                .flatten()
                .map { it.text.split('\n').drop(1).join('\n') }
        )
        .collectFile(
            name: filename, 
            storeDir: params.outdir,
            newLine: true,
            sort: false,
            cache: false
        )
}

def short_enabled() {
    params.short_vcf ? true : params.short_vcf_annotated ? true : false
}

def struc_enabled() {
    params.struc_vcf ? true : params.struc_vcf_annotated ? true : false
}



def get_short_fmt() {
    (params.short_format ?: []).toList().unique()
}

def get_short_inf() {
    (
        (params.short_info ?: []) + 
        (get_vcfanno_map().collectMany { it.fields.keySet() })
    ).unique()
}

def get_fmt(type) {
    if (type == 'SHORT') {
        return(get_short_fmt())
    }
    if (type == 'STRUC') {
        return(get_struc_fmt())
    }
}

def get_struc_fmt() {
    (params.struc_format ?: []).toList().unique()
}

def get_struc_inf() {
    (
        (params.struc_info ?: []) + 
        (['Max_AF', 'Max_Het', 'Max_HomAlt', 'Max_PopMax_AF']) // from SVAFotate
    ).unique()
}

def get_inf(type) {
    if (type == 'SHORT') {
        return(get_short_inf())
    }
    if (type == 'STRUC') {
        return(get_struc_inf())
    }
}

