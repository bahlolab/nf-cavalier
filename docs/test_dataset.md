# Test dataset — 1000G CEPH trio

An end-to-end example for nf-cavalier built from publicly available
1000 Genomes Project data: the **CEPH trio** of NA12878 (daughter) and her
parents NA12891 and NA12892, restricted to **chr22** to keep inputs small.

> **Caveat — demo framing only.** All three trio members are healthy
> reference samples. For this test the pedigree marks **both NA12878
> (daughter) and NA12891 (father)** as *affected* purely so the inheritance
> segregation logic has probands to filter against; coding two affecteds
> across generations surfaces more candidates than a single affected proband.
> Variants that surface should be interpreted as a demonstration of the
> pipeline, not a clinical finding.

## Data sources

| Item | Source |
|------|--------|
| Trio alignments (CRAM, GRCh38DH) | [Illumina Platinum Pedigree](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/illumina_platinum_pedigree/) |
| Joint-called SNV/INDEL/SV VCF (GRCh38, per-chromosome) | [1000G 3202 phased panel, 20220422 release](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000G_2504_high_coverage/working/20220422_3202_phased_SNV_INDEL_SV/) |
| Gene lists | `HGNC:protein-coding`, PanelApp Australia [Mendeliome (PAA:137)](https://panelapp-aus.org/panels/137/) and [PAA:126](https://panelapp-aus.org/panels/126/) (all auto-fetched) |
| Reference & annotations | Provided by `setup_anno` |

## Prerequisites

- nf-cavalier reference data already set up by running
  [setup_anno.nf](../setup_anno/setup_anno.nf) first. This downloads the GRCh38
  reference FASTA (`Homo_sapiens_assembly38.fasta`) along with the annotation
  sources and records its path as `params.ref_fasta` in the generated
  `nextflow.config`.
- `samtools`, `bcftools`, `curl` available in `PATH`.

## Prepare inputs

From the repository root, pass the reference FASTA downloaded by `setup_anno`
(its path is `params.ref_fasta` in your generated `nextflow.config`); it is used
to decode the upstream CRAMs:

```bash
bash tests/ceph_trio/download.sh -r /path/to/Homo_sapiens_assembly38.fasta
```

This populates `tests/ceph_trio/data/` with:

- `NA12878.chr22.bam` + `.bai` (and the same for NA12891/NA12892)
- `trio.chr22.short.vcf.gz` + `.csi` — SNVs and indels, trio samples only
- `trio.chr22.struc.vcf.gz` + `.csi` — structural variants, trio samples only

…and also writes two files next to `download.sh`:

- `alignments.tsv` — sample → BAM path mapping (absolute paths)
- `test_ceph_trio.config` — Nextflow config wiring all of the above into `params`
  (gene lists, looser demo filter thresholds, `qc_sce_vcf = false`)

For chr22, each BAM is ~1 GB and the VCFs are tens of MB. To slice a
different chromosome (e.g. chr1, ~8 GB BAMs), pass `-R chr1`.

The script decodes the upstream CRAMs against the reference FASTA but writes
plain BAM locally — that removes any reference-MD5 dependency from downstream
tools (samplot, IGV, etc.) which can otherwise fail on CRAM slice decode in
containerised runs.

Options: `-o OUTDIR`, `-R REGION`, `-t THREADS`. See `download.sh -h`.

## Run the pipeline

```bash
nextflow run . -c tests/ceph_trio/test_ceph_trio.config -resume
```

The generated `test_ceph_trio.config` only sets pipeline inputs (alignments,
VCFs, pedigree, gene lists, demo filter thresholds); reference annotation paths
still come from your `setup_anno`-generated `nextflow.config` (auto-loaded from
the run directory).

## Expected outputs

Under `output/`:

- `by_family/CEPH/CEPH.pdf` — slide deck of candidate variants
- `by_family/CEPH/CEPH.short.filtered_variants.csv` — candidate table
- `variant_browser.html` — interactive variant browser
- `qc/somalier/` — relatedness QC; should confirm the parent-offspring
  structure of the trio
