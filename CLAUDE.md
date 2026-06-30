# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Overview

**nf-cavalier** is a Nextflow DSL2 pipeline for singleton and family-based candidate
variant reporting from gene lists. It annotates, filters, visualises and reports both
short variants (SNVs/indels) and structural variants (SVs), producing candidate-variant
CSVs, per-family PowerPoint/PDF slide decks (with IGV/SVPV/samplot screenshots), and an
interactive HTML variant browser. Targets GRCh38. Maintained at WEHI (Bahlo lab).

## Running the pipeline

Requires Nextflow ≥ 24.04 and a container runtime (Docker / Singularity / Apptainer).

```bash
# Run (expects a nextflow.config with params in the run directory)
nextflow run nf-cavalier -resume

# WEHI/Bahlolab users — preconfigured annotation cache paths
nextflow run nf-cavalier -resume -profile bahlolab

# One-time reference-data setup (downloads sources, writes a populated nextflow.config)
nextflow run nf-cavalier/setup_anno/setup_anno.nf \
    --resource_dir ./cavalier_refdata --config_out ./nextflow.config
```

- `--annotate_only` stops after annotation (skips the `CAVALIER` filter/report stage).
- **Tests**: `tests/ceph_trio/` is an end-to-end 1000G CEPH trio (chr22) example. Run
  `tests/ceph_trio/download.sh` to fetch inputs, then run with `tests/ceph_trio/test_ceph_trio.config`.
  See [docs/test_dataset.md](docs/test_dataset.md). There is no nf-test suite or CI —
  validation is config-based via this dataset.

## Architecture / data flow

[main.nf](main.nf) wires four named workflows:

```
SETUP → QC + ANNOTATE → CAVALIER   (CAVALIER skipped if params.annotate_only)
```

- **SETUP** ([workflows/setup/main.nf](workflows/setup/main.nf)) — validates params, fetches
  & normalises gene lists to Ensembl IDs, intersects samples across VCFs/alignments/pedigree.
- **QC** ([workflows/qc/main.nf](workflows/qc/main.nf)) — somalier (relatedness/ancestry) and
  SCE-VCF (contamination).
- **ANNOTATE** ([workflows/annotate/main.nf](workflows/annotate/main.nf)) — delegates to the
  short/struc subworkflows.
- **CAVALIER** ([workflows/cavalier/main.nf](workflows/cavalier/main.nf)) — filters variants and
  generates CSVs, slide decks, and the HTML variant browser.

Annotation subworkflows ([subworkflows/local/](subworkflows/local/)) share a scatter/gather shape:
- `short.nf`: SCATTER → CLEAN → VCFANNO → VEP → GATHER
- `struc.nf`: SCATTER → CLEAN_STRUC → SVAFOTATE → VEP_STRUC → GATHER

## Repository layout

| Path | Contents |
|------|----------|
| [main.nf](main.nf) | Entry point; orchestrates the four workflows |
| [workflows/](workflows/) | `setup/`, `qc/`, `annotate/`, `cavalier/` — each a `main.nf` |
| [subworkflows/local/](subworkflows/local/) | `short.nf`, `struc.nf` annotation paths |
| [modules/local/](modules/local/) | One process per file (`vep.nf`, `filter.nf`, `make_slides.nf`, …) |
| [functions/](functions/) | Shared Groovy helpers: `helpers.nf`, `channels.nf`, `validate.nf`, `vep_helpers.nf`, `vcfanno_helpers.nf` |
| [bin/](bin/) | Scripts: R (`filter.R`, `make_slides.R`, `check_samples.R`, `init_cache.R`), Rmd (`variant_browser.Rmd`, `sce.Rmd`, `datatable.Rmd`), JS (`export_igv_png.js`), awk (`genepred_to_gff3.awk`) |
| [setup_anno/](setup_anno/) | Standalone reference-data download/preprocess pipeline |
| [tests/ceph_trio/](tests/) | End-to-end CEPH trio test dataset |
| [docs/](docs/) | Human documentation (see Docs pointers) |
| [nextflow.config](nextflow.config), [profiles.config](profiles.config), [nextflow_schema.json](nextflow_schema.json) | Configuration |

## Conventions

When editing or adding pipeline code, match the existing patterns:

- **Process modules** live one-per-file under `modules/local/` with snake_case filenames
  (`vep.nf`) and `UPPERCASE` process names (`VEP`). Each process opens with a comment block
  describing its intent and carries a `tag`.
- **Resource labels** encode CPUs/Mem/Time, e.g. `label 'C4M8T8'` (4 CPUs, 8 GB, 8 h). The
  values are defined in [nextflow.config](nextflow.config) and scale with `task.attempt`.
- **Container labels** are tool names, e.g. `label 'vep'`, also mapped to images in
  [nextflow.config](nextflow.config) `withLabel:` blocks. Don't hard-code containers in modules.
- **Optional features** are gated by `*_enabled()` helper functions (e.g. `spliceai_enabled()`,
  `short_enabled()`) in `functions/`, included via `include { ... } from '../../functions/...'`.
- Global `errorStrategy` retries (maxRetries 3) and `process.shell = ['/bin/bash','-euo','pipefail']`
  are set in [nextflow.config](nextflow.config) — rely on them rather than redefining per-process.
- Channels use `tuple val(id), path(files)` and are constructed via helpers in
  `functions/channels.nf`.

## Configuration

All parameters and process resource/container labels are in [nextflow.config](nextflow.config);
[profiles.config](profiles.config) defines the `bahlolab` profile (preconfigured cache paths);
[nextflow_schema.json](nextflow_schema.json) describes the params for validation. Notable groups:

- Primary I/O: `short_vcf`, `struc_vcf`, `alignments`, `ped`, `lists`, `outdir`.
- `FILTER_SHORT_*` / `FILTER_STRUC_*` — frequency/inheritance/impact filter thresholds
  (set a param to `null` to disable that filter).
- `SLIDE_INFO_SHORT` / `SLIDE_INFO_STRUC` — map params controlling slide-deck columns.
- Annotation sources: `vep_*`, `vcfanno_*`, `svafdb`, `ref_fasta`, `ref_gene`.

## Docs pointers

Defer to these for details rather than restating them:

- [README.md](README.md) — purpose, quick start, pipeline diagram.
- [docs/usage.md](docs/usage.md) — prerequisites, running, input file formats (alignments TSV, gene lists, pedigree).
- [docs/annotations.md](docs/annotations.md) — `setup_anno` and per-source download notes.
- [docs/parameters.md](docs/parameters.md) — every parameter with defaults.
- [docs/output.md](docs/output.md) — output directory layout.
- [docs/test_dataset.md](docs/test_dataset.md) — CEPH trio example.
- [CHANGELOG.md](CHANGELOG.md) — version history (current: 26.06.0, the "v2" rewrite).
