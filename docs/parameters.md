# Parameters

The following parameters may be set in the Nextflow configuration file.

`nextflow.config` (in the working directory) and `nextflow_schema.json` (in the pipeline directory) are the authoritative sources for parameter names and defaults; the tables below are the user-facing summary.

<details open>
<summary><b>Required</b></summary>

| Parameter | Default | Description |
|-----------|---------|-------------|
| `alignments` | - | TSV file with alignment file paths (Col 1: sample ID, Col 2: BAM or CRAM path) |
| `lists` | - | Gene lists, comma separated (TSV or ID) — see [usage.md#gene-lists](usage.md#gene-lists) |
| `short_vcf` *or* `struc_vcf` | - | Input VCF(s) for short variants (SNVs/Indels) and/or structural variants — at least one is required. Accepts `.vcf.gz` or `.bcf`, indexed with `.tbi` or `.csi` |
| `ped` | - | Pedigree file — required for familial analysis; omit for singletons — see [usage.md#pedigree](usage.md#pedigree) |

</details>

<details>
<summary><b>Annotation data — set by <code>setup_anno</code></b></summary>

These reference and annotation paths can be populated automatically by running the [`setup_anno`](annotations.md#annotation-setup-setup_anno) workflow, which writes them into a generated `nextflow.config`. Each is `null` by default; setting an entry to `null` disables the corresponding annotation (the pipeline will still run, but reporting will be less informative). `ref_fasta` and `vep_cache` are effectively required — VEP and IGV reports depend on them. SpliceAI files must be downloaded manually (see [annotations.md#spliceai-manual](annotations.md#spliceai-manual)).

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ref_fasta` | `null` | GRCh38 reference FASTA file |
| `vep_cache` | `null` | VEP cache directory — [see here](https://www.ensembl.org/info/docs/tools/vep/script/vep_cache.html) |
| `vep_cache_ver` | `'115'` | VEP cache version |
| `vep_spliceai_snv` | `null` | SpliceAI SNV VCF path — see [annotations.md#vep-plugins](annotations.md#vep-plugins) |
| `vep_spliceai_indel` | `null` | SpliceAI indel VCF path — see [annotations.md#vep-plugins](annotations.md#vep-plugins) |
| `vep_alphamissense` | `null` | AlphaMissense annotation TSV — see [annotations.md#vep-plugins](annotations.md#vep-plugins) |
| `vep_revel` | `null` | REVEL annotation TSV — see [annotations.md#vep-plugins](annotations.md#vep-plugins) |
| `vep_utr_annotator` | `null` | UTRannotator file — see [annotations.md#vep-plugins](annotations.md#vep-plugins) |
| `vcfanno_gnomad` | `null` | gnomAD 4.1 callset VCF with INFO: AC, AF, fafmax_faf95_max, nhomalt — see [annotations.md#gnomad-41](annotations.md#gnomad-41) |
| `vcfanno_cadd_snv` | `null` | CADD 1.7 SNV TSV — see [annotations.md#cadd](annotations.md#cadd) |
| `vcfanno_cadd_indel` | `null` | CADD 1.7 gnomAD indel TSV |
| `vcfanno_clinvar` | `null` | ClinVar VCF with INFO: CLNSIG, GENEINFO, ID — see [annotations.md#clinvar](annotations.md#clinvar) |
| `vcfanno_custom` | `null` | User-supplied vcfanno TOML config for additional custom annotations |
| `svafdb` | `null` | SVAFotate database (gnomAD v4.1 SV population frequencies) — see [annotations.md#svafotate](annotations.md#svafotate) |
| `ref_gene` | `null` | NCBI RefSeq Select (UCSC) TSV — [available here](https://genome.ucsc.edu/cgi-bin/hgTables?hgsid=3670191553_zqnYvk2x5XApGbDxqWZWmWYbAFNP&clade=mammal&org=&db=hg38&hgta_group=genes&hgta_track=refSeqComposite&hgta_table=ncbiRefSeqSelect&hgta_regionType=genome&position=&hgta_outputType=primaryTable&hgta_outFileName=ncbiRefSeqSelect.tsv) |
| `igv_ideogram` | `null` | Chromosome ideogram file in UCSC cytoBandIdeo format (`.txt` or `.txt.gz`) for IGV reports. When set alongside `ref_gene`, avoids runtime downloads from UCSC during parallel igv-reports runs. |
| `somalier_dir` | `null` | Somalier reference data directory (sites VCF, ancestry labels, 1KG bundle) |

</details>

<details>
<summary><b>General</b></summary>

| Parameter | Default | Description |
|-----------|---------|-------------|
| `outdir` | `'output'` | Output directory |
| `annotate_only` | `false` | Only performs annotation; no filtering or reporting of variants |
| `make_slides` | `true` | Output PPT/PDF slides |
| `vep_check` | `true` | Check that number of variants output by VEP equals number input |
| `cavalier_cache_dir` | `'cavalier_cache'` | Directory used by the cavalier R package for caching downloaded resources |

</details>

<details>
<summary><b>QC</b></summary>

| Parameter | Default | Description |
|-----------|---------|-------------|
| `qc_somalier` | `true` | Run somalier QC (relatedness, ancestry, contamination) |
| `qc_sce_vcf` | `true` | Run sample-contamination-estimate (SCE) QC on the input short variant VCF |
| `qc_sce_chr` | `'chr1,chr2,chr3'` | Comma-separated chromosomes used for SCE QC |

</details>

<details>
<summary><b>Short Variant Processing</b></summary>

`short_vcf_filter` is applied to the raw input VCF before vcfanno/VEP; `short_vcfanno_filter` is applied after vcfanno (it drops common variants to reduce VEP runtime).

| Parameter | Default | Description |
|-----------|---------|-------------|
| `short_vcf_annotated` | `null` | Pre-annotated short variant VCF (skips annotation) |
| `short_n_shards` | `200` | Split input VCF into shards for parallel processing |
| `short_vcf_filter` | `"PASS,."` | Pre-annotation FILTER values to retain (comma-separated) |
| `short_info` | `['AC', 'AF', 'AN']` | INFO fields to keep from input VCF |
| `short_format` | `['GT', 'GQ', 'DP']` | FORMAT fields to keep from input VCF (GT must be present) |
| `short_fill_tags` | `false` | Fill AC, AF, AN tags using bcftools +fill-tags (recommended if VCF does not have these set) |
| `short_vcfanno_filter` | `gnomad_AF<0.01 \|\| gnomad_AF="."` | bcftools-style expression applied after vcfanno, before VEP |

</details>

<details>
<summary><b>Short Variant Filters</b></summary>

Variants are reported if they pass the depth/quality and population/cohort frequency filters **and** match one of the enabled variant classes (`FILTER_SHORT_LOF`, `_MISSENSE`, `_SPLICING`, `_PROMOTER`, `_OTHER`). The `TYPE='OTHER'` class is controlled by `FILTER_SHORT_VEP_MIN_IMPACT` and, optionally, the additional `FILTER_SHORT_VEP_CONSEQUENCES` list. `FILTER_SHORT_MIN_CADD_PP` and `FILTER_SHORT_MIN_SPLICEAI_PP` force-include high-scoring variants regardless of class.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FILTER_SHORT_MIN_DP` | `5` | Minimum read depth |
| `FILTER_SHORT_MIN_GQ` | `10` | Minimum genotype quality |
| `FILTER_SHORT_POP_DOM_MAX_AF` | `0.0001` | Max population (gnomAD) AF for dominant variants |
| `FILTER_SHORT_POP_REC_MAX_AF` | `0.01` | Max population (gnomAD) AF for recessive variants |
| `FILTER_SHORT_POP_DOM_MAX_AC` | `10` | Max population (gnomAD) AC for dominant variants |
| `FILTER_SHORT_POP_REC_MAX_AC` | `1000` | Max population (gnomAD) AC for recessive variants |
| `FILTER_SHORT_POP_DOM_MAX_HOM` | `1` | Max population (gnomAD) homozygotes for dominant variants |
| `FILTER_SHORT_POP_REC_MAX_HOM` | `10` | Max population (gnomAD) homozygotes for recessive variants |
| `FILTER_SHORT_COH_DOM_MAX_AF` | `null` | Max cohort AF for dominant variants |
| `FILTER_SHORT_COH_REC_MAX_AF` | `null` | Max cohort AF for recessive variants |
| `FILTER_SHORT_COH_DOM_MAX_AC` | `null` | Max cohort AC for dominant variants |
| `FILTER_SHORT_COH_REC_MAX_AC` | `null` | Max cohort AC for recessive variants |
| `FILTER_SHORT_CLINVAR_LIST_ONLY` | `true` | Restrict ClinVar variant reporting to genes in the gene list only |
| `FILTER_SHORT_CLINVAR_KEEP_PAT` | `(p\|P)athogenic(?!ity)` | Regex pattern of ClinVar `CLNSIG` values to keep (matches "pathogenic" but not "pathogenicity") |
| `FILTER_SHORT_CLINVAR_DISC_PAT` | `(b\|B)enign` | Regex pattern of ClinVar `CLNSIG` values to discard |
| `FILTER_SHORT_LOF` | `true` | Enable TYPE='LOF' (VEP IMPACT == 'HIGH') |
| `FILTER_SHORT_MISSENSE` | `true` | Enable TYPE='MISSENSE' (VEP Consequence contains 'missense') |
| `FILTER_SHORT_SPLICING` | `true` | Enable TYPE='SPLICING' |
| `FILTER_SHORT_PROMOTER` | `false` | Enable TYPE='PROMOTER' (uses PromoterAI score) |
| `FILTER_SHORT_OTHER` | `true` | Enable TYPE='OTHER' (variants meeting `FILTER_SHORT_VEP_MIN_IMPACT` / `FILTER_SHORT_VEP_CONSEQUENCES`) |
| `FILTER_SHORT_MIN_CADD_PP` | `25.3` | Minimum CADD Phred score to force inclusion (ClinGen PP3 supporting threshold) |
| `FILTER_SHORT_MIN_SPLICEAI_PP` | `0.20` | Minimum SpliceAI score to force inclusion (ClinGen PP3 supporting threshold) |
| `FILTER_SHORT_VEP_MIN_IMPACT` | `'MODERATE'` | Minimum VEP IMPACT to retain as TYPE='OTHER' (one of: MODIFIER, LOW, MODERATE, HIGH) |
| `FILTER_SHORT_VEP_CONSEQUENCES` | `null` | Additional VEP Consequence terms to retain as TYPE='OTHER' (comma-separated) |
| `FILTER_SHORT_MAX_PROMOTERAI` | `-0.50` | Maximum PromoterAI score for TYPE='PROMOTER' variants. Thresholds: `-0.5` high precision, `-0.2` balanced, `-0.1` high recall (decreased-expression direction) |

</details>

<details>
<summary><b>Structural Variant Processing</b></summary>

| Parameter | Default | Description |
|-----------|---------|-------------|
| `struc_vcf_annotated` | `null` | Pre-annotated structural variant VCF (skips annotation) |
| `struc_n_shards` | `20` | Number of shards for parallel SV processing |
| `struc_vcf_filter` | `"PASS,."` | Pre-annotation FILTER values to retain (comma-separated) |
| `struc_info` | `['AC', 'AF', 'AN', 'SVTYPE', 'SVLEN', 'END']` | INFO fields to keep from input VCF |
| `struc_format` | `['GT']` | FORMAT fields to keep from input VCF (GT must be present) |
| `struc_fill_tags` | `false` | Fill AC, AF, AN tags for SVs |

</details>

<details>
<summary><b>Structural Variant Filters</b></summary>

| Parameter | Default | Description |
|-----------|---------|-------------|
| `FILTER_STRUC_POP_DOM_MAX_AF` | `0.0001` | Max population AF for dominant SVs |
| `FILTER_STRUC_POP_REC_MAX_AF` | `0.01` | Max population AF for recessive SVs |
| `FILTER_STRUC_POP_DOM_MAX_HOM` | `null` | Max population homozygotes for dominant SVs |
| `FILTER_STRUC_POP_REC_MAX_HOM` | `null` | Max population homozygotes for recessive SVs |
| `FILTER_STRUC_COH_DOM_MAX_AF` | `0.01` | Max cohort AF for dominant SVs |
| `FILTER_STRUC_COH_REC_MAX_AF` | `0.01` | Max cohort AF for recessive SVs |
| `FILTER_STRUC_COH_DOM_MAX_AC` | `null` | Max cohort AC for dominant SVs |
| `FILTER_STRUC_COH_REC_MAX_AC` | `null` | Max cohort AC for recessive SVs |
| `FILTER_STRUC_SVTYPES` | `'DEL,DUP,INS,INV'` | SV types to retain (BND is currently excluded upstream due to a VEP issue) |
| `FILTER_STRUC_VEP_MIN_IMPACT` | `'LOW'` | Minimum VEP IMPACT for SVs (one of: MODIFIER, LOW, MODERATE, HIGH) |
| `FILTER_STRUC_VEP_CONSEQUENCES` | `'coding_sequence_variant,non_coding_transcript_exon_variant,TFBS_ablation,regulatory_region_ablation'` | Additional VEP Consequence terms to retain for SVs |
| `FILTER_STRUC_LARGE_LENGTH` | `null` | Automatically report SVs larger than this length (bp); `null` disables |

</details>

<details>
<summary><b>Reporting</b></summary>

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_short_per_deck` | `500` | Maximum number of short variants per slide deck |
| `max_struc_per_deck` | `500` | Maximum number of structural variants per slide deck |
| `SLIDE_INFO_SHORT` | *(map)* | Fields to include in short variant slides — see [usage.md#slide-info](usage.md#slide-info) |
| `SLIDE_INFO_STRUC` | *(map)* | Fields to include in structural variant slides — see [usage.md#slide-info](usage.md#slide-info) |

</details>

---

[Home](../README.md) · [Usage](usage.md) · [Annotations](annotations.md) · **Parameters** · [Output](output.md) · [Test Dataset](test_dataset.md)

