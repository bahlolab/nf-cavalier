
/* ----------- funtions ----------------*/
include { list_channels      } from '../../functions/helpers'
include { path               } from '../../functions/helpers'
include { date_ymd           } from '../../functions/helpers'
include { get_cavalier_opts  } from '../../functions/helpers'
include { cache_dir_channel  } from '../../functions/channels.nf'
include { get_local_lists    } from '../../functions/helpers.nf'
include { get_external_lists } from '../../functions/helpers.nf'

/* ----------- processes ----------------*/
include { INIT_CACHE       } from '../../modules/local/init_cache'
include { REF_GENE_GFF3    } from '../../modules/local/ref_gene_gff3.nf'
include { STORE            } from '../../modules/local/store.nf'
include { CHECK_SAMPLES    } from '../../modules/local/check_samples.nf'
include { VCF_SAMPLES as SHORT_SAMPLES } from '../../modules/local/vcf_samples.nf'
include { VCF_SAMPLES as STRUC_SAMPLES } from '../../modules/local/vcf_samples.nf'
include { alignment_channel } from '../../functions/channels.nf'
include { pedigree_channel } from '../../functions/channels.nf'

workflow SETUP {
    /*
        - Initialise cavalier
        - Pull down latest versions of gene lists
        - Normalised gene_ids (i.e. convert to ensemble)
        - Emit lists and set of all genes (as ensembl_gene_ids)
        - Check and intersect sample sets
    */
    main:

    if (params.annotate_only)  {
        
        STORE(
            Channel.value(['vcfanno', path(params.vcfanno_binary)])
        )    
        pedigree_channel  = Channel.empty()
        alignment_channel = Channel.empty()
        check             = Channel.value(true)

    } else {
        INIT_CACHE(
            date_ymd(),
            get_cavalier_opts(),
            cache_dir_channel(),
            get_local_lists(),
            get_external_lists()
        )
       
        STORE(
            INIT_CACHE.out.genes
                .flatten()
                .mix(INIT_CACHE.out.options)
                .map { [((it.name =~ /(.+)\.([a-f0-9]+)\.(tsv|txt|json)$/)[0][1]), it] }
                .mix(Channel.value(['vcfanno', path(params.vcfanno_binary)]))
        )    

        def short_vcf_in = params.short_vcf ?: params.short_vcf_annotated
        def struc_vcf_in = params.struc_vcf ?: params.struc_vcf_annotated

        short_samples = short_vcf_in ? SHORT_SAMPLES(Channel.value(path(short_vcf_in))) : Channel.value([])
        struc_samples = struc_vcf_in ? STRUC_SAMPLES(Channel.value(path(struc_vcf_in))) : Channel.value([])

        CHECK_SAMPLES(
            path(params.alignments),
            params.ped ? path(params.ped) : [],
            short_samples,
            struc_samples
        )

        CHECK_SAMPLES.out.warnings.readLines().flatten().map { log.warn(it)}

        pedigree_channel = pedigree_channel(CHECK_SAMPLES.out.ped)

        alignment_channel = alignment_channel(CHECK_SAMPLES.out.alignments, CHECK_SAMPLES.out.ped)

        check = CHECK_SAMPLES.out.check
    }

    // samplot gene track: convert the RefSeq Select genePred (same file SVPV uses)
    // to a bgzipped, tabix-indexed GFF3 once; [] when not configured / annotate_only
    ref_gene_gff = (!params.annotate_only && params.ref_gene)
        ? REF_GENE_GFF3(path(params.ref_gene)).first()
        : []

    emit:
    cavalier_opts     = STORE.out.filter { it.name ==~ /.+\.json$/  }.first()
    lists             = STORE.out.filter { it.name ==~ /.+\.tsv$/   }.collect()
    gene_set          = STORE.out.filter { it.name ==~ /.+\.txt$/   }.first()
    vcfanno_binary    = STORE.out.filter { it.name ==~ /.*vcfanno.*/}.first()
    pedigree_channel  = pedigree_channel
    alignment_channel = alignment_channel
    versions          = INIT_CACHE.out.versions
    check             = check
    ref_gene_gff      = ref_gene_gff
}