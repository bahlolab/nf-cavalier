# Changelog: nf-cavalier
<!--- https://keepachangelog.com/en/1.0.0/ --->

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