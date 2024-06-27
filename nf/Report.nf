
include { pedigree_channel; bam_channel; pop_sv_channel; ref_gene_channel; make_path; get_options_json } from './functions'
include { Lists } from './Lists'

workflow Report {
    take:
        input // set, vcf, tbi, fam, aff, unaff

    main:

   cavalier_input = input |
        map { it[[0,1,3,4,5]] } |
        family_subset |
        map { it[[1,0,2]] } | //fam, set, vcf
        combine(pedigree_channel(), by:0) |
        combine(bam_channel(), by:0) | //fam, set, vcf, ped, sam, bam, bai
       map { it[[1,0,2,3,4,5,6]] }  //set, fam, vcf, ped, sam, bam, bai

    cavalier(cavalier_input, Lists(), make_path(params.cache_dir))

    // create pdf from pptx
    cavalier.out |
        map { it[0..2] } |
        pptx_to_pdf

    // run svpv on candidate SVs
    cavalier.out |
        filter { it[0] == 'SV' } |
        filter { it[4].toFile().readLines().size() > 1 } |
        map { it[[1,3]] } | //fam, vcf
        combine( cavalier_input |
                     filter { it[0] == 'SV' } |
                     map { it[[1,4,5,6]] }, // fam, sam, bam, bai,
                 by:0 ) |
        combine(pop_sv_channel()) |
        combine(ref_gene_channel()) |
        svpv

    // report SNP and SV candidates
    candidates = cavalier.out |
        map { it[4] } |
        splitCsv(header: true) |
        branch { snp: it.set == 'SNP'; sv: true }

    candidates.snp |
        first |
        map { (it.keySet() as List).join(',') } |
        concat(
            candidates.snp |
                map { (it.values() as List).join(',') } |
                toSortedList |
                flatten
        ) |
        collectFile(name: "SNP_candidates.csv", storeDir: params.outdir,
                    newLine:true, sort: false, cache: false)

    candidates.sv |
        first |
        map { (it.keySet() as List).join(',') } |
        concat(
            candidates.sv |
                map { (it.values() as List).join(',') } |
                toSortedList |
                flatten
        ) |
        collectFile(name: "SV_candidates.csv", storeDir: params.outdir,
                    newLine:true, sort: false, cache: false)

}

process family_subset {
    label 'C2M2T2'
    publishDir "${params.outdir}/family_subset", mode: 'copy'
    tag { "$fam:$set" }

    input:
    tuple val(set), path(vcf), val(fam), val(aff), val(unaff)

    output:
    tuple val(set), val(fam), path(out_vcf), path("${out_vcf}.tbi")

    script:
    out_vcf = "${set}.${fam}.subset.vcf.gz"
    """
    printf "${aff.join('\\n')}\\n" > aff
    bcftools view --no-update $vcf -Ou -s ${(aff + unaff).join(',')} |
        bcftools view  -i "GT[@aff]='alt'" -Oz -o $out_vcf
    bcftools index -t $out_vcf
    """
}

process cavalier {
    label 'C2M4T2'
    label 'cavalier'
    publishDir "${params.outdir}/cavalier", mode: 'copy', pattern: "*.pptx"
    publishDir "${params.outdir}/cavalier", mode: 'copy', pattern: "*.filter_stats.csv"
    tag { "$fam:$set" }

    input:
    tuple val(set), val(fam), path(vcf), path(ped), val(sam), path(bam), path(bai)
    path lists
    path cache_dir
    path variants_override
    

    output:
    tuple val(set), val(fam), path("${pref}.pptx"), path("${pref}.candidates.vcf.gz"),
          path("${pref}.candidates.csv"), path("${pref}.filter_stats.csv")

    script:
    pref = "$fam.$set"
    sam_bam = [sam, bam instanceof List ? bam: [bam]]
        .transpose().collect {it.join('=') }.join(' ')
    optional =(
        (set == 'SV' ? ['--sv']: []) +
        (params.exclude_benign_missense ? ['--exclude-benign-missense']: []) +
        (params.include_sv_csv ? ['--include-sv-csv']: []) +
        (params.no_slides ? ['--no-slides']: [])
        (variants_override.name != 'VARIANTS_OVERRIDE': ["--variants-override $variants_override"] : [])
    ).join(' ')
    """
    cavalier_wrapper.R $vcf $ped $sam_bam $optional \\
        --out $pref \\
        --family $fam \\
        --caller $params.snp_caller \\
        --gene-lists ${lists.join(',')} \\
        --maf-dom $params.maf_dom \\
        --maf-de-novo $params.maf_de_novo \\
        --maf-rec $params.maf_rec \\
        --maf-comp-het $params.maf_comp_het \\
        --max-cohort-af $params.max_cohort_af \\
        --max-cohort-ac $params.max_cohort_ac \\
        --min-impact $params.min_impact \\
        --cavalier-options '${get_options_json()}'
    """
}

process pptx_to_pdf {
    container 'linuxserver/libreoffice:7.6.7'
    memory '4G'
    tag { "$fam:$set" }
    publishDir "${params.outdir}/cavalier", mode: 'copy', pattern: "*.pdf"
    
    input:
    tuple val(set), val(fam), path(pptx)

    output:
    tuple val(set), val(fam), path(pdf)

    script:
    pdf = pptx.name.replaceAll('.pptx', '.pdf')
    """
    HOME=\$PWD soffice --headless --convert-to pdf $pptx || echo 'done'
    """
}

process svpv {
    label 'C2M4T2'
    publishDir "${params.outdir}/svpv", mode: 'copy'
    tag { fam }

    input:
    tuple val(fam), path(vcf), val(sam), path(bam), path(bai), path(pop_sv), path(pop_sv_indx), path(ref_gene)

    output:
    tuple val(fam), path(output)

    script:
    output = "$fam"
    sam_bam = [sam, bam instanceof List ? bam : [bam]]
        .transpose().collect { it.join('=') }.join(' ')
    """
    SVPV \\
        -o $output \\
        -samples ${sam.join(',')} \\
        -aln ${bam.join(',')} \\
        -vcf $vcf \\
        -ref_vcf gnomAD:$pop_sv \\
        -ref_gene $ref_gene
    """
}