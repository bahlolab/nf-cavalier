
include { fasta_downloads          } from '../functions/setup_helpers'
include { abs                      } from '../functions/setup_helpers'
include { write_generated_config   } from '../functions/setup_helpers'

include { FETCH as FETCH_FASTA               } from '../modules/fetch'
include { FETCH as FETCH_ALPHAMISSENSE       } from '../modules/fetch'
include { FETCH as FETCH_UTR_ANNOTATOR       } from '../modules/fetch'
include { FETCH as FETCH_CADD_SNV            } from '../modules/fetch'
include { FETCH as FETCH_CADD_SNV_TBI        } from '../modules/fetch'
include { FETCH as FETCH_CADD_INDEL          } from '../modules/fetch'
include { FETCH as FETCH_CADD_INDEL_TBI      } from '../modules/fetch'
include { FETCH as FETCH_SVAFOTATE           } from '../modules/fetch'
include { FETCH as FETCH_SOMALIER_SITES      } from '../modules/fetch'
include { FETCH as FETCH_SOMALIER_LABELS     } from '../modules/fetch'
include { FETCH as FETCH_SOMALIER_1KG        } from '../modules/fetch'

include { TABIX as TABIX_ALPHAMISSENSE       } from '../modules/tabix'
include { TABIX as TABIX_SVAFOTATE           } from '../modules/tabix'

include { VEP_CACHE                } from '../modules/vep_cache'
include { GNOMAD                   } from '../modules/gnomad'
include { CLINVAR                  } from '../modules/clinvar'
include { REF_GENE                 } from '../modules/ref_gene'
include { REVEL                    } from '../modules/revel'

workflow SETUP_ANNO {

    // Per-asset channels emit [asset_name, primary_file] for downloaded assets.
    // Skipped assets contribute nothing; the config writer detects them via params.skip_*.

    ch_assets = Channel.empty()

    if (!params.skip_ref_fasta) {
        // Fan three FETCH tasks over the fasta/fai/dict triple, then pick the .fasta as the primary.
        fasta_tasks = Channel.fromList(fasta_downloads(params.url_ref_fasta_base))
            .map { url, name -> tuple('ref_genome', url, name) }
        FETCH_FASTA(fasta_tasks)
        ch_assets = ch_assets.mix(
            FETCH_FASTA.out.filter { it.name.endsWith('.fasta') }.map { f -> tuple('ref_fasta', f) }
        )
    }

    if (!params.skip_vep_cache) {
        ch_assets = ch_assets.mix(
            VEP_CACHE(params.url_vep_cache).map { dir -> tuple('vep_cache', dir.parent.parent) }
            // VEP_CACHE outputs homo_sapiens/<ver>_GRCh38 — config points at the parent (vep_cache root).
        )
    }

    if (!params.skip_alphamissense) {
        am = FETCH_ALPHAMISSENSE(tuple('alphamissense', params.url_alphamissense, 'AlphaMissense_hg38.tsv.gz'))
        am_tbi = TABIX_ALPHAMISSENSE(am.map { f -> tuple('alphamissense', f, '-s 1 -b 2 -e 2 -S 1') })
        ch_assets = ch_assets.mix(
            am.combine(am_tbi).map { primary, _tbi -> tuple('alphamissense', primary) }
        )
    }

    if (!params.skip_revel) {
        if (!params.url_revel) {
            log.warn "[setup_anno] url_revel is null — REVEL will be omitted from generated config."
        } else {
            ch_assets = ch_assets.mix(
                REVEL(params.url_revel).map { tsv, _tbi -> tuple('revel', tsv) }
            )
        }
    }

    if (!params.skip_utr_annotator) {
        ch_assets = ch_assets.mix(
            FETCH_UTR_ANNOTATOR(tuple('utr_annotator', params.url_utr_annotator, 'uORF_5UTR_GRCh38_PUBLIC.txt'))
                .map { f -> tuple('utr_annotator', f) }
        )
    }

    if (!params.skip_gnomad) {
        GNOMAD(params.url_gnomad_pattern, Channel.fromList(params.gnomad_chrs))
        ch_assets = ch_assets.mix(GNOMAD.out.map { vcf, _tbi -> tuple('gnomad', vcf) })
    }

    if (!params.skip_cadd) {
        cadd_snv     = FETCH_CADD_SNV(tuple('cadd', params.url_cadd_snv, 'whole_genome_SNVs.tsv.gz'))
        cadd_snv_tbi = FETCH_CADD_SNV_TBI(tuple('cadd', params.url_cadd_snv + '.tbi', 'whole_genome_SNVs.tsv.gz.tbi'))
        ch_assets = ch_assets.mix(
            cadd_snv.combine(cadd_snv_tbi).map { primary, _tbi -> tuple('cadd_snv', primary) }
        )

        cadd_indel     = FETCH_CADD_INDEL(tuple('cadd', params.url_cadd_indel, 'gnomad.genomes.r4.0.indel.tsv.gz'))
        cadd_indel_tbi = FETCH_CADD_INDEL_TBI(tuple('cadd', params.url_cadd_indel + '.tbi', 'gnomad.genomes.r4.0.indel.tsv.gz.tbi'))
        ch_assets = ch_assets.mix(
            cadd_indel.combine(cadd_indel_tbi).map { primary, _tbi -> tuple('cadd_indel', primary) }
        )
    }

    if (!params.skip_clinvar) {
        ch_assets = ch_assets.mix(CLINVAR(params.url_clinvar).map { vcf, _tbi -> tuple('clinvar', vcf) })
    }

    if (!params.skip_svafotate) {
        def svaf_name = 'SVAFotate_core_SV_popAFs.GRCh38.v4.1.bed.gz'
        sv = FETCH_SVAFOTATE(tuple('svafotate', params.url_svafotate, svaf_name))
        sv_tbi = TABIX_SVAFOTATE(sv.map { f -> tuple('svafotate', f, '-p bed') })
        ch_assets = ch_assets.mix(
            sv.combine(sv_tbi).map { primary, _tbi -> tuple('svafotate', primary) }
        )
    }

    if (!params.skip_ref_gene) {
        ch_assets = ch_assets.mix(REF_GENE(params.url_ref_gene).map { f -> tuple('ref_gene', f) })
    }

    if (!params.skip_somalier) {
        sites  = FETCH_SOMALIER_SITES(tuple('somalier', params.url_somalier_sites,           'sites.hg38.vcf.gz'))
        labels = FETCH_SOMALIER_LABELS(tuple('somalier', params.url_somalier_ancestry_labels, 'ancestry-labels-1kg.tsv'))
        kg1    = FETCH_SOMALIER_1KG(tuple('somalier', params.url_somalier_1kg,                '1kg.somalier.tar.gz'))
        // cavalier expects a directory containing all 3 files.
        ch_assets = ch_assets.mix(
            sites.combine(labels).combine(kg1).map { s, _l, _k -> tuple('somalier', s.parent) }
        )
    }

    // Collect all resolved [name, path] pairs and write the config.
    ch_assets
        .map { name, p -> tuple(name, abs(p)) }
        .toList()
        .subscribe { resolved ->
            write_generated_config(resolved)
        }
}
