# Changelog: nf-cavalier
<!--- https://keepachangelog.com/en/1.0.0/ --->

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
