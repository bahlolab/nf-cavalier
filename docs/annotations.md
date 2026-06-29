# Annotations

nf-cavalier annotates variants with VEP (plus several plugins), vcfanno (gnomAD, CADD, ClinVar) and SVAFotate. Reference data for GRCh38 can be set up automatically with the [`setup_anno`](#annotation-setup-setup_anno) workflow, or downloaded manually using the per-source notes further down.

## Annotation Setup (`setup_anno`)
A separate workflow under [`setup_anno/`](../setup_anno/) automates retrieval and preprocessing of (almost) all required reference annotation data for GRCh38, and writes a populated `nextflow.config` ready for the main pipeline.

Basic invocation:
```
nextflow run /PATH/TO/nf-cavalier/setup_anno/setup_anno.nf \
    --resource_dir ./cavalier_refdata \
    --config_out   ./nextflow.config
```
* `--resource_dir` — where all downloaded reference data will be stored (default `./cavalier_refdata`). Files are kept via `storeDir` so reruns short-circuit completed downloads.
* `--config_out` — path the generated `nextflow.config` will be written to. The workflow **fails if this file already exists** to avoid overwriting an existing config.

Each asset can be opted-out with the corresponding `--skip_<asset>` flag. Skipped assets are commented out in the generated config; wire those paths in manually. Download URLs are all parameters with defaults (`--url_<asset>`) — override if an upstream URL changes.

Skip flags: `skip_ref_fasta`, `skip_vep_cache`, `skip_alphamissense`, `skip_revel`, `skip_utr_annotator`, `skip_gnomad`, `skip_cadd`, `skip_clinvar`, `skip_svafotate`, `skip_ref_gene`, `skip_somalier`.

## Per-source download notes
If you prefer to source files manually (or `setup_anno` was opted out of an asset), follow the per-source instructions below. The parameter names listed under each source match the ones in [parameters.md](parameters.md).

### CADD
* CADD 1.7 downloads are available [here](https://cadd.gs.washington.edu/download), required files:
  * `whole_genome_SNVs.tsv.gz`
  * `whole_genome_SNVs.tsv.gz.tbi`
  * `gnomad.genomes.r4.0.indel.tsv.gz`
  * `gnomad.genomes.r4.0.indel.tsv.gz.tbi`
* Set parameters `vcfanno_cadd_snv` and `vcfanno_cadd_indel`.

### ClinVar
* ClinVar VCFs and TBI may be downloaded [here](https://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/weekly/).
* These should be regularly updated to keep results current.
* Set parameter `vcfanno_clinvar`.

### GnomAD 4.1
* The joint callset is available [here](https://gnomad.broadinstitute.org/data#v4-joint-freq-stats).
* Chromosomal VCFs need to be downloaded, merged into a single file, and indexed (this can be done with `bcftools`).
* Extracting only the required annotations — `AC`, `AF`, `fafmax_faf95_max`, `nhomalt` — will reduce file size massively (`bcftools annotate -x`).
* Set parameter `vcfanno_gnomad`.

### VEP Plugins
Cavalier uses several VEP plugins. See the following links for download details:
  * [REVEL](https://www.ensembl.org/info/docs/tools/vep/script/vep_plugins.html#revel)
  * [SpliceAI](https://www.ensembl.org/info/docs/tools/vep/script/vep_plugins.html#spliceai) (see also [SpliceAI (manual)](#spliceai-manual) below — files cannot be auto-downloaded)
  * [UTRannotator](https://www.ensembl.org/info/docs/tools/vep/script/vep_plugins.html#utrannotator)
  * [AlphaMissense](https://www.ensembl.org/info/docs/tools/vep/script/vep_plugins.html#alphamissense)

Set parameters `vep_spliceai_snv`, `vep_spliceai_indel`, `vep_revel`, `vep_utr_annotator` and `vep_alphamissense`.

### SVAFotate
* [SVAFotate](https://github.com/fakedrtom/SVAFotate) is used to annotate gnomAD v4.1 SV frequencies.
* The database file is available [here](https://zenodo.org/records/11642574).
* Set parameter `svafdb`.

## SpliceAI (manual)
SpliceAI raw score files are distributed only via Illumina BaseSpace and require a free Illumina account. They are **not** auto-downloaded by `setup_anno` — `vep_spliceai_snv` and `vep_spliceai_indel` are always emitted as commented-out placeholders in the generated config; fill them in manually after downloading.

To obtain the files: sign in at https://basespace.illumina.com, open https://basespace.illumina.com/s/otSPW8hnhaZR, accept the non-commercial license, and download from `genome_scores_v1.3`:
* `spliceai_scores.raw.snv.hg38.vcf.gz`
* `spliceai_scores.raw.indel.hg38.vcf.gz`

Generate tabix indexes locally (`tabix -p vcf <file.vcf.gz>` for each), then point the two `vep_spliceai_*` params at the resulting paths.

---

[Home](../README.md) · [Usage](usage.md) · **Annotations** · [Parameters](parameters.md) · [Output](output.md) · [Test Dataset](test_dataset.md)
