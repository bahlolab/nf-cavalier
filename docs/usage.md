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

- **Variant VCFs** — at least one of `short_vcf` (SNVs/Indels) or `struc_vcf` (structural variants). Joint-called multi-sample VCFs are expected.
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
