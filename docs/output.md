# Outputs

All outputs land under `${params.outdir}` (default `output/`). The layout is:

```
${outdir}/
├── <cohort>.bcf, <cohort>.bcf.csi            # gathered annotated VCFs (short and/or SV)
├── variant_browser.html                      # interactive HTML browser of candidates
├── by_gene_counts.csv                        # per-gene candidate counts across families
├── cavalier_options.*.json                   # snapshot of cavalier options used
├── by_family/
│   └── <family_id>/
│       ├── <family_id>.*.filtered_variants.csv   # candidate variant table(s)
│       ├── <family_id>.*.filtering.png           # filtering summary plot
│       ├── <family_id>.*.reason_filtered.csv.gz  # per-variant filter reasons
│       ├── <family_id>.*.igv_report.html         # IGV.js read-pile screenshots
│       ├── <family_id>.pptx                      # candidate slide deck (PowerPoint)
│       ├── <family_id>.pdf                       # candidate slide deck (PDF)
│       ├── samplot/                              # samplot PNGs for SVs
│       └── svpv/                                 # SVPV plots for SVs
├── by_gene/
│   └── *.pdf                                 # per-gene slide aggregates
└── qc/
    ├── somalier/...                          # somalier relatedness / ancestry
    ├── sce.html, sce.*.tsv                   # sample-contamination-estimate (SCE) QC
    └── *-tbl.html                            # supporting QC tables
```

## Per-family outputs (`by_family/<family_id>/`)

These are the primary deliverables — one slide deck plus supporting results per family.

- **`<family_id>.pptx` / `<family_id>.pdf`** — slide decks containing one slide per candidate variant, with gene/variant info, pedigree, IGV screenshots, and (for SVs) SVPV / samplot plots.
- **`<family_id>.<type>.filtered_variants.csv`** — the table of candidates that pass all filters for this family (one file per variant type: short, structural).
- **`<family_id>.<type>.reason_filtered.csv.gz`** — for each variant that was *removed* by a filter, the filter step that dropped it. Useful for auditing why an expected variant is missing.
- **`<family_id>.<type>.filtering.png`** — Sankey/funnel plot of how many variants survived each filter stage.
- **`<family_id>.<type>.igv_report.html`** — standalone IGV.js HTML showing read pileups at each candidate site.
- **`samplot/`, `svpv/`** — image directories used by the slide decks; safe to ignore for review.

## Cohort-wide outputs

- **`variant_browser.html`** — interactive HTML table of all candidates across all families. Useful for cohort level variant search.
- **`by_gene_counts.csv`** — number of candidates per gene, aggregated across the cohort.
- **`by_gene/*.pdf`** — slide aggregates grouped by gene (useful when reviewing one gene across many families).
- **`<cohort>.bcf` / `.bcf.csi`** — the fully annotated variant VCFs (post-VEP, post-vcfanno) gathered from shard processing. Useful as input to `short_vcf_annotated` / `struc_vcf_annotated` on a follow-up run to skip annotation.

## QC outputs (`qc/`)

- **`somalier/`** — `qc_somalier=true` produces relatedness, ancestry and contamination reports from somalier.
- **`sce.html`, `sce.*.tsv`** — `qc_sce_vcf=true` runs sample-contamination-estimate (SCE) on the input short variant VCF over `qc_sce_chr` chromosomes.
- **`*-tbl.html`** — small HTML tables surfaced inside the variant browser.

## Miscellaneous

- **`cavalier_options.*.json`** — the resolved options the [cavalier R package](https://github.com/bahlolab/cavalier) was invoked with. Kept for provenance.

---

[Home](../README.md) · [Usage](usage.md) · [Annotations](annotations.md) · [Parameters](parameters.md) · **Output** · [Test Dataset](test_dataset.md)

