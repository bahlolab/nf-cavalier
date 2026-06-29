# Changelog: nf-cavalier
<!--- https://keepachangelog.com/en/1.0.0/ --->

## [26.06.0](https://github.com/bahlolab/nf-cavalier/releases/tag/26.06.0) - 29 Jun 2026
Major rewrite ("nf-cavalier v2"): the flat `nf/` process layout is replaced by a
modular DSL2 pipeline, with joint short/structural variant analysis, automated
reference-data setup, and an interactive HTML variant browser.
### Added
- Interactive HTML variant browser (`variant_browser.html`): filterable short- and
  structural-variant tables with per-variant detail panels, embedded IGV/SVPV/
  samplot/UCSC views, and live lookups to HGNC, NCBI Gene/PubMed, ClinVar,
  gnomAD, PanelApp (Australia + GEL), HPO and All of Us, with an API health bar
- QC workflow: somalier relatedness + ancestry (1KG reference) and SCE-VCF sample
  contamination estimation, surfaced as variant-browser tabs and standalone reports
- Automated reference-data setup workflow (`setup_anno/`) that downloads and
  preprocesses all GRCh38 resources (reference FASTA, VEP cache, gnomAD 4.1, CADD,
  ClinVar, REVEL, AlphaMissense, UTRannotator, SVAFotate, RefSeq Select, IGV
  ideogram, somalier) and writes a populated `nextflow.config`
- VEP plugins: AlphaMissense, SpliceAI (SNV + indel), REVEL, UTRannotator, and
  optional promoterAI; vcfanno annotation with gnomAD, CADD (SNV + indel) and ClinVar
- Structural-variant path: SVAFotate gnomAD-SV frequencies, VEP consequences, and
  samplot visualisation with a RefSeq Select gene track (alongside SVPV)
- Input support for BCF VCFs and `.csi` indexes, and CRAM alignments (`.crai`)
- Genes4Epilepsy (`G4E:`) gene lists
- `params.annotate_only` to stop after annotation
- End-to-end 1000G CEPH trio (chr22) test dataset under `tests/ceph_trio/`
- `docs/` documentation set (usage, annotations, parameters, output, test dataset)
  and a rewritten README with a mermaid pipeline diagram
- `bahlolab` profile in `profiles.config`
### Changed
- Restructured the pipeline into DSL2 workflows (SETUP → QC → ANNOTATE → CAVALIER),
  subworkflows (`short`, `struc`), single-purpose modules and reusable functions
- Short and structural inputs are now separate parameters (`short_vcf`/`struc_vcf`),
  alignments are supplied via an alignments TSV, and annotation reference data is
  configured per source
- VEP bumped to v115; intermediate variants gathered as indexed BCF
- Audited and restructured `nextflow.config` / `nextflow_schema.json`; moved
  Bahlolab-specific paths into the `bahlolab` profile
- IGV reports use local ideogram/refgene files instead of fetching from UCSC at runtime

## [24.06.0](https://github.com/bahlolab/nf-cavalier/releases/tag/24.06.0) - 27 Jun 2024
### Added
- `params.cavalier_options` to pass arbitrary options to cavalier package
- support for Genes4Epilepsy lists with "G4E" prefix
- switch to ensembl_gene_id as primary gene identifier, but also accept hgnc_id, symbol or entrez_id
- output pdf in addition to powerpoint slides
- `params.database_mode` to control how online data resource are used
### Fixed
- Breaking changes to HPO API fixed in cavalier R pacakge
### Changed
- `params.lists` now specifies lists for whole batch, removed ability to run specific gene lists for each families (if required this should  be done in a separate run). This simplifies set-up for a typical use cases.
- remove `params.id` in favour of using `params.outdir` to name outputs

## [23.03.1](https://github.com/bahlolab/nf-cavalier/releases/tag/23.03.1) - 17 Mar 2023
### Added
- support for mutect2 variant calls
- pedigree validity detection and correction in cavalier package

## [22.07.1](https://github.com/bahlolab/nf-cavalier/releases/tag/22.07.1) - 04 Jul 2022
### Added
- "filter stats" csv output to cavalier_wrapper.R to keep track of reasons variants are filtered
### Fixed
- Problem in cavalier::hgnc_sym2sym function causing some gene names to be incorrect

## [22.03.2](https://github.com/bahlolab/nf-cavalier/releases/tag/22.03.2) - 23 Mar 2022
### Fixed
- Some diseases missing from HPO API causing errors, switch to using phenotype_annotation.tab artifact from hpo.annotations in cavalier

## [22.03.1](https://github.com/bahlolab/nf-cavalier/releases/tag/22.03.1) - 22 Mar 2022
### Added
- SV support, SVPV visualisation
- Candidate variants CSV output summarising all candidate variants across all samples
### Fixed
- Test code resulting in warning `2 samples in "vcf" but not in "ped" or "bams": a_sam, b_sam` removed
### Changed
- Merge cavalier-pre and cavalier containers, install the majority of R packages with conda for faster builds
- PanelApp list versions save to cavalier cache to avoid downloading repeatedly across pipelines
- Reorganise Nextflow code into discrete modules to simplify main.nf
- Set Cavalier cache dir explicitly in Nextflow pipeline to avoid singularity not recognising home directory issue

## [21.10.2](https://github.com/bahlolab/nf-cavalier/releases/tag/21.10.2) - 29 Oct 2021
### Fixed
- VEP cache directory not passed as Nextflow Path, causing directory not to be mounted in Singularity images.
### Added
- Warnings when sample IDs and family IDs in inputs are unmatched.
- Splitting of input VCF based on genomic intervals to speed VCF preprocessing.
- Param `exclude_benign_missense` to allow control whether benign missense variants are excluded from results.
### Changed
- Switched to BCF instead of VCF.gz format for intermediate tasks
- Dropped unused VEP annotations `--mane`, `--var_synonyms`, `--pubmed`,`--af_esp`, `--gene_phenotype`, `--appris`,
  `--tsl`, `--uniprot`, `--biotype`, `--canonical`,`--regulatory` and `--domains`
- Dropped VEP filter options `--allow_non_variant` and `--dont_skip`.
- Combined `vep` and `vep_filter` processes into process `vep`.
- Combined `vcf_split`and `vcf_flatten_multi` into new process `vcf_split_norm`. 
- process `vep` now outputs 3 files: '\*.vep.bcf' for annotated variants to be passed to Cavalier, '\*.vep-modifier.bcf'
for annotated variants categorised as 'MODIFIER' and '.unannotated.bcf' for variants not annotated by VEP
(intergenic/invariant/failed reference check).

## [21.10.1](https://github.com/bahlolab/nf-cavalier/releases/tag/21.10.1) - 13 Oct 2021
### Notes
- First release
