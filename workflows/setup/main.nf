
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
include { STORE            } from '../../modules/local/store.nf'
include { GET_SAMPLES      } from '../../modules/local/get_samples.nf'
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

        GET_SAMPLES(
            path(params.alignments),
            params.ped ? path(params.ped) : [],
            params.short_vcf ? path(params.short_vcf) : (params.short_vcf_annotated ? path(params.short_vcf_annotated) : []),
            params.struc_vcf ? path(params.struc_vcf) : (params.struc_vcf_annotated ? path(params.struc_vcf_annotated) : [])
        )

        GET_SAMPLES.out.warnings.readLines().flatten().map { log.warn(it)}

        pedigree_channel = pedigree_channel(GET_SAMPLES.out.ped)

        alignment_channel = alignment_channel(GET_SAMPLES.out.alignments, GET_SAMPLES.out.ped)

        check = GET_SAMPLES.out.check
    }

    emit:
    cavalier_opts     = STORE.out.filter { it.name ==~ /.+\.json$/  }.first()
    lists             = STORE.out.filter { it.name ==~ /.+\.tsv$/   }.collect()
    gene_set          = STORE.out.filter { it.name ==~ /.+\.txt$/   }.first()
    vcfanno_binary    = STORE.out.filter { it.name ==~ /.*vcfanno.*/}.first()
    pedigree_channel  = pedigree_channel
    alignment_channel = alignment_channel
    versions          = INIT_CACHE.out.versions
    check             = check
}