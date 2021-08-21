#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/* TODO:
    inputs:
        - vcf
        - bam_manifest [sample, bam]
            - csv file
        - pedigree [family, sample, pid, mid, sex, phenotype]
            - tsv file, no column names
        - gene_lists [family, list_name, list_path]
            - csv file, one list per line
    gene_lists:
        - csv file, single required column 'gene'
        - additional metadata columns will be reported by cavalier
    checks:
        - check pedigree (don't necessarily expected all family members to have sample)
            - check at least one affected sample per family in VCF
        - check samples in vcf, pedigree and bam_manifest
        - check families in gene lists
        - report similar to peddy
    pedigree:
        - function read_ped(), return list of map
        - function group_ped(), return list of [family, [affected...], [unaffected...]]
        - collectFile() to split into sub pedigrees for input to cavalier
        - multipe models can be used for a given family by using different family_ids for each
    bam_manifest:
        - combine with pedigree to add in family
    tweaks:
        - pre-filter VCF by select only samples in manifest/pedigree and only alternate alleles
 */

params.id = ''
params.vcf = ''
params.ped = ''
params.bams = ''
params.lists = ''
params.n_split = 100
params.vep_cache = ''
params.vep_cache_ver = ''
params.vep_assembly = ''
params.max_af = 0.10
params.vep_impact = ['MODERATE', 'HIGH']
params.maf_dom = 0.0001
params.maf_rec = 0.01
params.maf_comp_het = 0.01
params.max_cohort_af = 0.10
params.omim_genemap2 = '/stornext/Bioinf/data/lab_bahlo/ref_db/human/OMIM/OMIM_2021-08-17/genemap2.txt'
params.ref_fasta = ''


include { path; read_tsv; get_families } from './nf/functions'

include { vcf_sample_list } from './nf/vcf_sample_list'
include { vcf_split } from './nf/vcf_split'
include { vcf_flatten_multi } from './nf/vcf_flatten_multi'
include { vep } from './nf/vep'
include { vep_filter } from './nf/vep_filter'
include { vcf_merge } from './nf/vcf_merge'
include { vcf_family_subset } from './nf/vcf_family_subset'
include { cavalier } from './nf/cavalier'

vcf = path(params.vcf)
tbi = path(params.vcf + '.tbi')
ped = read_tsv(path(params.ped), ['fid', 'iid', 'pid', 'mid', 'sex', 'phe'])
bams = read_tsv(path(params.bams), ['iid', 'bam'])
lists = read_tsv(path(params.lists), ['fid', 'list'])
omim_genemap2 = path(params.omim_genemap2)
ref_fasta = path(params.ref_fasta)
ref_fai = path(params.ref_fasta + '.fai')

workflow {

    families = vcf_sample_list(vcf) |
        map { [it.toFile().readLines() as ArrayList] } |
        combine(get_families(ped)) |
        map { sm, fam, af, un -> [fam, af.intersect(sm), un.intersect(sm)] } |
        // Note: families silently dropped here if no affected members in VCF
        filter { it[1].size() > 0 }

    ped_channel = Channel.from(ped) |
        map { it.values() as ArrayList } |
        collectFile(newLine:true) {
            [ "${it[0]}.ped", it.join('\t')]
        } |
        map { [it.name.replaceAll('.ped', ''), it] }

    list_channel = Channel.from(lists) |
        map { [it.fid, path(it.list)] } |
        groupTuple(by: 0)

    bam_channel = Channel.from(bams) |
        map { [it.iid, path(it.bam)] } |
        combine(ped.collect { [it.iid, it.fid] }, by: 0) |
        map { it[[2,0,1]] } |
        groupTuple(by: 0)

    Channel.value([vcf, tbi]) |
        vcf_split |
        flatten |
        map { [it.name.replaceFirst(params.id + '-', '').replaceFirst('.vcf.gz', ''), it] } |
        vcf_flatten_multi |
        combine([[ref_fasta, ref_fai]]) |
        vep |
        vep_filter |
        toSortedList |
        transpose |
        toList |
        map { it[1..2] } |
        vcf_merge |
        map { it[0] } |
        combine(families) |
        vcf_family_subset |
        map { it[0..1] } |
        combine(ped_channel, by:0) |
        combine(list_channel, by:0) |
        combine(bam_channel, by:0) |
        combine([omim_genemap2]) |
        cavalier
}