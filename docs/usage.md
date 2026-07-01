# Usage

## Prerequisites
* [Nextflow](https://www.nextflow.io/) >= 24.04
* A container runtime: [Docker](https://www.docker.com/), [Singularity](https://sylabs.io/singularity/) or [Apptainer](https://apptainer.org/)

## Installation
Clone the repository:
```
git clone https://github.com/bahlolab/nf-cavalier.git
```

## Running the pipeline
1. Create and navigate to a run working directory.
2. **Set up reference data** — either run the included [`setup_anno`](annotations.md#annotation-setup-setup_anno) workflow (recommended) or download files manually using the per-source notes in [annotations.md](annotations.md).
3. **Create a configuration file** named `nextflow.config` in the run directory — see [parameters.md](parameters.md) for all options. Minimal example:
    ```nextflow
    params {
        // Inputs
        alignments = 'alignments.tsv'
        ped        = 'family.ped'          // omit for singletons
        short_vcf  = 'cohort.snv.vcf.gz'
        struc_vcf  = 'cohort.sv.vcf.gz'
        lists      = 'PAA:202,my_genes.tsv'
    }
    ```
    See [Input files](#input-files) below for the formats expected for `alignments`, `lists`, and `ped`.
4. **Run the pipeline**:
    ```
    nextflow run /PATH/TO/nf-cavalier -resume
    ```

## Bahlolab users
Bahlolab users do not need to download annotation sources; use the preconfigured profile:
```
nextflow run /PATH/TO/nf-cavalier -resume -profile bahlolab
```

## Test dataset
An end-to-end example built from the public **1000G CEPH trio** (chr22) is provided in `tests/ceph_trio/`. See [test_dataset.md](test_dataset.md) for how to download the inputs and run it.

## Input files

The pipeline takes four kinds of input:

- **Variant VCFs** — at least one of `short_vcf` (SNVs/Indels) or `struc_vcf` (structural variants). Joint-called multi-sample VCFs are expected. Bgzipped VCF (`.vcf.gz`) or BCF (`.bcf`) are both accepted, with a `.tbi` or `.csi` index sitting alongside.
- **Alignments TSV** — maps sample IDs to BAM/CRAM files for the IGV / SVPV / Samplot screenshots in slide decks.
- **Gene list(s)** — one or more lists (local or web-based) that drive variant filtering.
- **Pedigree** — required for familial analysis; omit for singletons.

See [parameters.md](parameters.md) for the parameter names and defaults.

### Alignments TSV
A tab-separated file with two columns and **no header row**:

1. **Sample ID** — must match a sample name in the input VCF(s).
2. **Alignment path** — absolute (or run-dir relative) path to a BAM or CRAM file. The index (`.bai` / `.crai`) must sit alongside.

Example:
```
sample_001  /data/alignments/sample_001.cram
sample_002  /data/alignments/sample_002.cram
```

### Gene Lists
Gene lists are passed as a comma-separated set of gene lists to use for filtering. Each entry may be a local TSV file (e.g. `my_gene_list.tsv`) or a web-based gene list (e.g. [PAA:289](https://panelapp.agha.umccr.org/panels/289/)).

#### Local TSV file
Path to a gene list TSV file. The file should have at least one of the following column names: `ensembl_gene_id`, `hgnc_id`, `entrez_id` or `symbol`. Optional column names are `list_id`, `list_name`, `list_version` and `inheritance` (used for display in the reports — no fixed vocabulary, but conventional codes such as `AD`, `AR`, `XD`, `XR` are typical). All gene IDs are converted to Ensembl Gene IDs using HGNC to match the VEP annotation.

Example using `symbol`:

```
list_id	list_name	list_version	symbol	inheritance
PAA:202	Genetic Epilepsy	1.26	AARS1	AR
PAA:202	Genetic Epilepsy	1.26	ABAT	AR
PAA:202	Genetic Epilepsy	1.26	ABCA2	AR
```

Or using `ensembl_gene_id`:

```
list_id	list_name	list_version	ensembl_gene_id	inheritance
PAA:202	Genetic Epilepsy	1.26	ENSG00000090861	AR
PAA:202	Genetic Epilepsy	1.26	ENSG00000183044	AR
PAA:202	Genetic Epilepsy	1.26	ENSG00000107331	AR
```

#### Web lists
Cavalier automatically retrieves the latest version of these web lists. Prefix the list ID to select the source:

| Prefix | Source | Example |
|--------|--------|---------|
| `PAA:` | PanelApp Australia | `PAA:202` ([panel 202](https://panelapp-aus.org/panels/202/)) |
| `PAE:` | PanelApp Genomics England | `PAE:489` |
| `HP:`  | Human Phenotype Ontology term | `HP:0001250` ([HP:0001250](https://hpo.jax.org/browse/term/HP:0001250)) |
| `G4E:` | [Genes4Epilepsy](https://github.com/bahlolab/Genes4Epilepsy) — options: `ALL`, `Focal`, `MCD`, `DEE`, `PME`, `GGE` | `G4E:Focal` |
| `HGNC:` | HGNC locus group | `HGNC:protein-coding` |

#### Genomic region
A literal genomic region such as `chr1:1000000-2000000` — cavalier will extract all ensembl/gencode genes in that region.

### Pedigree
When provided, only variants that segregate perfectly with phenotype will be reported.

Format is a TSV file with 6 columns (standard PLINK/PED format) and **no header row**:

1. **Family ID**
2. **Individual ID**
3. **Paternal ID** — use `0` if unknown / founder
4. **Maternal ID** — use `0` if unknown / founder
5. **Sex** — `1` male, `2` female, `0` unknown
6. **Phenotype** — `1` unaffected, `2` affected, `0` unknown / missing

### Slide Info
Output slides contain a table reporting variant- and gene-level information. The columns shown are controlled by the `SLIDE_INFO_SHORT` and `SLIDE_INFO_STRUC` map parameters.

- `DEFAULT` fields are reported for every variant.
- Named sections (`MISSENSE`, `SPLICING`, `PROMOTER`, `OTHER`) add type-specific columns that are appended only for variants of that type.

The defaults for short and structural variants are:

```nextflow
params {
    SLIDE_INFO_SHORT = [
        DEFAULT: [
            Gene         : 'Gene',
            Inheritance  : 'inheritance',
            Consequence  : 'Consequence',
            HGVS         : 'HGVS',
            ClinVar      : 'CLNSIG',
            'gnomAD v4.1': 'gnomAD',
            Cohort       : 'Cohort',
            PhyloP100    : 'phyloP100',
            'CADD v1.7'  : 'CADD',
        ],
        MISSENSE: [
            REVEL        : 'REVEL',
            AlphaMissense: 'AlphaMissense',
            SIFT         : 'SIFT',
            PolyPhen     : 'PolyPhen',
        ],
        SPLICING: [
            SpliceAI     : 'SpliceAI',
        ],
        PROMOTER: [
            PromoterAI   : 'promoterAI',
        ],
        OTHER: [
            SpliceAI     : 'SpliceAI',
        ],
    ]
    SLIDE_INFO_STRUC = [
        DEFAULT: [
            Gene         : 'Gene',
            Inheritance  : 'inheritance',
            Consequence  : 'Consequence',
            HGVS         : 'HGVS',
           'SV Type'     : 'SVTYPE',
            Region       : 'Region',
            Length       : 'SVLEN',
            'gnomAD v4.1': 'gnomAD',
            Cohort       : 'Cohort',
        ],
    ]
}
```

## Filtering and Prioritisation

This section explains *how* and *why* variants are filtered, so you can tune the thresholds to your disease of interest. The full parameter list with defaults is in [parameters.md](parameters.md#short-variant-filters); the explanation below covers the model behind the frequency filters in particular.

### How variants are filtered

For each family (or singleton), a candidate variant must pass **all** of the following to be reported:

1. **Variant class** — for short variants, an enabled class (`LOF`, `MISSENSE`, `SPLICING`, `PROMOTER`, `OTHER`) determined from VEP impact/consequence and, where relevant, CADD / SpliceAI / PromoterAI scores. For structural variants, an allowed SV type (`FILTER_STRUC_SVTYPES`) and VEP impact/consequence (`FILTER_STRUC_VEP_MIN_IMPACT`, `FILTER_STRUC_VEP_CONSEQUENCES`); SVs longer than `FILTER_STRUC_LARGE_LENGTH` are reported automatically.
2. **Gene list** — it must fall in a gene from one of your `lists`.
3. **Inheritance and frequency** — it must segregate with the phenotype **and** be rare enough under the frequency thresholds for its inheritance mode (see below).
4. **Genotype quality** (short variants only) — each contributing genotype must meet `FILTER_SHORT_MIN_DP` (depth, default `5`) and `FILTER_SHORT_MIN_GQ` (genotype quality, default `10`). Structural-variant calls have no depth/quality filter.

Variant class and gene-list membership decide *whether a variant is the kind we care about*; the frequency filters decide *whether it is rare enough to be plausibly causal*. The frequency step is where disease-specific tuning matters most.

### Dominant vs recessive frequency regimes

nf-cavalier does **not** apply a single frequency cut-off. Each variant is first assigned an observed inheritance mode from how it segregates with affected/unaffected status, and that mode selects which frequency thresholds apply:

- **dominant** — affected individuals are heterozygous (HET) and unaffected individuals are reference (REF).
- **recessive** — affected individuals are homozygous (HOM) and no unaffected individual is HOM.

For a **singleton** (one affected sample, no pedigree) this reduces to zygosity: a **heterozygous** call is evaluated under the **dominant** thresholds, and a **homozygous** call under the **recessive** thresholds.

The two regimes exist because the expected population frequency of a causal allele differs by inheritance mode — a dominant disease allele should be very rare in the population, whereas a recessive allele can be carried (heterozygously) at appreciable frequency. Accordingly the defaults are much stricter for dominant variants:

- `FILTER_SHORT_POP_DOM_MAX_AF = 0.0001` (dominant)
- `FILTER_SHORT_POP_REC_MAX_AF = 0.01` (recessive)

A heterozygous variant that is too common for the dominant threshold but still within the recessive threshold is **not discarded** — it is reclassified as a `compound` candidate and retained for compound-heterozygous analysis (it is reported only if a second qualifying hit is found in the same gene).

### Population vs cohort frequency

Two independent frequency sources are checked, each with its own dominant/recessive thresholds:

- **Population (`POP`)** — gnomAD allele frequencies. `POP` AF uses the higher of gnomAD AF and the 95% filtering allele frequency (FAF95); `POP` also exposes allele count (`AC`) and homozygote count (`HOM`, gnomAD `nhomalt`). Use these to exclude variants that are too common in the general population.
- **Cohort (`COH`)** — frequencies computed from *your own* joint-called VCF (`AF`, `AC`). Use these to suppress variants that are common **within your cohort** — typically recurrent sequencing artefacts or shared common variants — which population databases may not flag.

Setting any threshold to `null` disables that particular check (it never removes a variant).

### Key frequency parameters and defaults

Short-variant frequency filters (structural-variant equivalents use the `FILTER_STRUC_*` prefix):

| Parameter | Default | Applies to | Effect |
|-----------|---------|------------|--------|
| `FILTER_SHORT_POP_DOM_MAX_AF` | `0.0001` | dominant (HET) | Max gnomAD AF/FAF95 |
| `FILTER_SHORT_POP_REC_MAX_AF` | `0.01` | recessive (HOM) | Max gnomAD AF/FAF95 |
| `FILTER_SHORT_POP_DOM_MAX_AC` | `null` (off) | dominant | Max gnomAD allele count |
| `FILTER_SHORT_POP_REC_MAX_AC` | `null` (off) | recessive | Max gnomAD allele count |
| `FILTER_SHORT_POP_DOM_MAX_HOM` | `null` (off) | dominant | Max gnomAD homozygote count |
| `FILTER_SHORT_POP_REC_MAX_HOM` | `null` (off) | recessive | Max gnomAD homozygote count |
| `FILTER_SHORT_COH_DOM_MAX_AF` | `null` (off) | dominant | Max cohort AF |
| `FILTER_SHORT_COH_REC_MAX_AF` | `null` (off) | recessive | Max cohort AF |
| `FILTER_SHORT_COH_DOM_MAX_AC` | `null` (off) | dominant | Max cohort allele count |
| `FILTER_SHORT_COH_REC_MAX_AC` | `null` (off) | recessive | Max cohort allele count |

By default only the population **AF** filters are active; the AC, HOM and cohort filters are off (`null`) and can be enabled as needed. Structural variants follow the same `DOM`/`REC` × `POP`/`COH` pattern (`FILTER_STRUC_POP_DOM_MAX_AF = 0.0001`, `FILTER_STRUC_POP_REC_MAX_AF = 0.01`; population AC is not used for SVs).

### Choosing thresholds for your disease

The population AF thresholds effectively cap the **maximum credible frequency of a disease allele** — as a rule of thumb it should not exceed the disease prevalence, adjusted for penetrance and inheritance mode. Adjust the defaults when your disease does not fit them:

- **Rare, highly penetrant dominant disorder** — tighten `POP_DOM_MAX_AF` below the `0.0001` default to reduce false positives; setting `POP_DOM_MAX_HOM = 0` (no population homozygotes) is a strong additional filter.
- **Recessive disorder with a common carrier allele** (e.g. founder variants) — raise `POP_REC_MAX_AF` above `0.01` to admit the real allele, optionally bounding by `POP_REC_MAX_HOM` so alleles seen homozygous in healthy individuals are still removed.
- **Recurrent cohort artefacts** — enable the `COH_*` filters to drop variants common within your own cohort even when gnomAD does not flag them.

### Variants retained regardless of frequency

- **ClinVar pathogenic** — variants whose ClinVar `CLNSIG` matches `FILTER_SHORT_CLINVAR_KEEP_PAT` (default matches "pathogenic") are retained even if they exceed the frequency thresholds, provided they still segregate with the phenotype. `FILTER_SHORT_CLINVAR_DISC_PAT` (default "benign") discards matching benign classifications.
- **CADD / SpliceAI / PromoterAI** scores influence only the **variant class** assignment (`FILTER_SHORT_MIN_CADD_PP`, `FILTER_SHORT_MIN_SPLICEAI_PP`, `FILTER_SHORT_MAX_PROMOTERAI`); they do **not** exempt a variant from the frequency or segregation filters.

See [parameters.md](parameters.md#short-variant-filters) for the complete list of filter parameters, including the variant-class flags and ClinVar settings.

---
> [Home](../README.md) &ensp;·&ensp; **Usage** &ensp;·&ensp; [Annotations](annotations.md) &ensp;·&ensp; [Parameters](parameters.md) &ensp;·&ensp; [Output](output.md) &ensp;·&ensp; [Test Dataset](test_dataset.md)
