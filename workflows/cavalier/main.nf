
/* ----------- funtions ----------------*/
include { path              } from '../../functions/helpers'
include { get_filter_opts   } from '../../functions/helpers'
include { collect_csv       } from '../../functions/helpers'
include { cache_dir_channel } from '../../functions/channels'
include { get_slide_info    } from '../../functions/helpers.nf'
include { get_inf           } from '../../functions/helpers.nf'
include { get_fmt           } from '../../functions/helpers.nf'
include { get_fam_aff_un    } from '../../functions/helpers.nf'
include { short_enabled     } from '../../functions/helpers.nf'
include { struc_enabled     } from '../../functions/helpers.nf'
include { ref_fasta_channel } from '../../functions/channels'


/* ----------- processes ----------------*/
include { SPLIT_VEP   } from '../../modules/local/split_vep'
include { FILTER      } from '../../modules/local/filter.nf'
include { IGV_REPORT  } from '../../modules/local/igv_report'
include { IGV_TO_PNG  } from '../../modules/local/igv_to_png.nf'
include { SAMPLOT     } from '../../modules/local/samplot.nf'
include { SVPV        } from '../../modules/local/svpv.nf'
include { SVPV_TO_PNG } from '../../modules/local/svpv_to_png.nf'
include { MAKE_SLIDES } from '../../modules/local/make_slides.nf'
include { PPT_TO_PDF  } from '../../modules/local/ppt_to_pdf'
include { PDF_UNITE   } from '../../modules/local/pdf_unite.nf'
include { PDF_COPY    } from '../../modules/local/pdf_copy.nf'
include { PDF_SPLIT   } from '../../modules/local/pdf_split.nf'
include { VAR_BROWSER } from '../../modules/local/var_browser.nf'

workflow CAVALIER {
    take:
    gene_set
    lists
    cavalier_opts
    short_vcf
    struc_vcf
    pedigree_channel
    alignment_channel
    check

    main:
    /*
        - Filter and report variants
    */
    SPLIT_VEP(
        short_vcf.map { ['SHORT'] + it }
            .mix(struc_vcf.map { ['STRUC'] + it })
            .map { it + [get_inf(it[0]), get_fmt(it[0])] }
            .combine(get_fam_aff_un(pedigree_channel, alignment_channel)),
        check
    )

    split_short = SPLIT_VEP.out.tsv.filter {it[0] == 'SHORT' }.map { it[[1,2]] }
    split_struc = SPLIT_VEP.out.tsv.filter {it[0] == 'STRUC' }.map { it[[1,2]] }

    if (short_enabled() & struc_enabled()) {
        filter_input = split_short.join(split_struc) // fam, short, struc
    } else if (short_enabled()) {
        filter_input = split_short.map { [it[0], it[1], []] } // fam, short, []
    } else {
        filter_input = split_struc.map { [it[0], [], it[1]] } // fam, [], struc
    }

    FILTER(
        filter_input.combine(pedigree_channel, by: 0),
        gene_set,
        get_filter_opts(),
        cavalier_opts,
        cache_dir_channel()
    )

    /* ----- Visualise short variants ----- */
    short_count = FILTER.out.short_count
        .map    { [it[0], it[1].text as int] }
    
    samples_short = short_count
        .filter { it[1] > 0 }
        .map    { it[0]     }
    
    samples_short_zero = short_count
        .filter { it[1] == 0 }
        .map    { it[0]      }
    
    short_count
        .filter { it[1] > params.max_short_per_deck }
        .map    { it[0] }
        .toList()
        .filter { it.size() > 0 }
        .map { 
            log.warn("${it.size()} samples with more than ${params.max_short_per_deck} short variants - slides will be truncated")
        }

    IGV_REPORT(
        FILTER.out.short_igv.map { [it[0], it[1].text.trim()] }
            .join(samples_short)
            .join(pedigree_channel)
            .join(SPLIT_VEP.out.vcf.filter {it[0] == 'SHORT' }.map { it[[1,2,3]] })
            .join(alignment_channel),
        ref_fasta_channel(),
        path("$projectDir/misc/igv_report_mod.txt")
    )
 
    IGV_TO_PNG(
        IGV_REPORT.out.individual
    )

    /* ----- Visualise struct variants ----- */
    struc_count = FILTER.out.struc_count
        .map    { [it[0], it[1].text as int] }

    samples_struc = struc_count
        .filter { it[1] > 0 }
        .map    { it[0]     } 

    samples_struc_zero = struc_count
        .filter { it[1] == 0 }
        .map    { it[0]      } 

    struc_count
        .filter { it[1] > params.max_struc_per_deck }
        .map    { it[0] }
        .toList()
        .filter { it.size() > 0 }
        .map { 
            log.warn("${it.size()} samples with more than ${params.max_struc_per_deck} struc variants - slides will be truncated")
        }
        
    SVPV(
        SPLIT_VEP.out.vcf.filter { it[0] == 'STRUC' }.map { it[[1,2]] } // fam, vcf
            .join(samples_struc)
            .join(FILTER.out.struc_lines.map { [it[0], it[1].text.trim()] }) // fam, vcf, lines
            .join(alignment_channel), // fam, vcf, csv, ids, bams, bais
        path(params.ref_gene),
        ref_fasta_channel()
    )

    SVPV_TO_PNG(
        SVPV.out
    )

    SAMPLOT(
        FILTER.out.struc_samplot.map { [it[0], it[1].text.trim()] }
            .join(samples_struc)
            .join(alignment_channel),
        ref_fasta_channel()
    )

    if (params.make_slides) {
        /* ----- Create Slides ----- */
        fam_ch  = pedigree_channel.map { it [0] }
        null_ch = fam_ch.map { [it, []]}
        if (short_enabled()) {
            short_var      = fam_ch.join(FILTER.out.short_rds)
            short_flt_plot = fam_ch.join(FILTER.out.short_flt_plot)
            igv            = fam_ch.join(IGV_TO_PNG.out).mix(fam_ch.join(samples_short_zero).map { [it, []] })
        } else {
            short_var      = null_ch
            short_flt_plot = null_ch
            igv            = null_ch
        }
        if (struc_enabled()) {
            struc_var      = fam_ch.join(FILTER.out.struc_rds)
            struc_flt_plot = fam_ch.join(FILTER.out.struc_flt_plot)
            svpv           = fam_ch.join(SVPV_TO_PNG.out).mix(fam_ch.join(samples_struc_zero).map { [it, []] })
            samplot        = fam_ch.join(SAMPLOT.out).mix(fam_ch.join(samples_struc_zero).map { [it, []] })
        } else {
            struc_var      = null_ch
            struc_flt_plot = null_ch
            svpv           = null_ch
            samplot        = null_ch
        }
        MAKE_SLIDES(   
            pedigree_channel           // fam, ped
                .join(short_var)       // fam, ped, short_var
                .join(short_flt_plot)  // fam, ped, short_var, short_flt
                .join(igv)             // fam, ped, short_var, short_flt, igv
                .join(struc_var)       // fam, ped, short_var, short_flt, igv, struc_var
                .join(struc_flt_plot)  // fam, ped, short_var, short_flt, igv, struc_var, struc_flt
                .join(svpv)            // fam, ped, short_var, short_flt, igv, struc_var, struc_flt, svpv
                .join(samplot),        // fam, ped, short_var, short_flt, igv, struc_var, struc_flt, svpv, samplot
            lists,
            get_slide_info(),
            cavalier_opts,
            cache_dir_channel()
        )

        PPT_TO_PDF(
            MAKE_SLIDES.out
        )

        /* ----- Create PDFs by gene ----- */
        PDF_SPLIT(
            PPT_TO_PDF.out
        )

        by_gene = 
            PDF_SPLIT.out.flatten()
            .map  { [(it.name =~ /__([^.]+)__/)[0][1], it] }
            .groupTuple()

        PDF_UNITE(
            by_gene.filter { it[1].size() >  1 }
        )

        PDF_COPY(
            by_gene.filter { it[1].size() == 1 }
        )

        by_gene
            .map { [it[0], it[1].size()] }
            .toSortedList { it[0] }
            .map { "SYMBOL,n_samples\n" + it.collect { it.join(',') }.join('\n') }
            .collectFile(name: 'by_gene_counts.csv',storeDir: "${params.outdir}")
    }

    /* ----- Save CSV results ----- */
    short_cand = collect_csv(
        FILTER.out.short_csv.combine(samples_short, by:0).map { it[1] },
        'short_candidates.csv'
    )

    struc_cand = collect_csv(
        FILTER.out.struc_csv.combine(samples_struc, by:0).map { it[1] },
        'struc_candidates.csv'
    )

    if (params.make_slides) {
        VAR_BROWSER(
            path("${projectDir}/bin/variant_browser.Rmd"),
            short_cand,
            struc_cand,
            PDF_SPLIT.out          .flatMap{ it[1] }.map{ it.name }.collectFile(newLine:true, sort:true, name: 'slides.txt'),
            IGV_REPORT.out.combined.flatMap{ it[1] }.map{ it.name }.collectFile(newLine:true, sort:true, name: 'igv_report.txt'),
            SVPV.out               .flatMap{ it[1] }.map{ it.name }.collectFile(newLine:true, sort:true, name: 'svpv.txt'),
            SAMPLOT.out            .flatMap{ it[1] }.map{ it.name }.collectFile(newLine:true, sort:true, name: 'samplot.txt')
        )
    }

}
