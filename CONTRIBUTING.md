# Contributing to nf-cavalier

Thank you for your interest in contributing. This guide covers how to report bugs,
propose features, and submit code changes.

## Reporting bugs and requesting features

Please open a [GitHub issue](https://github.com/bahlolab/nf-cavalier/issues) with:

- A clear description of the problem or feature request.
- For bugs: the Nextflow version, container runtime and version, and the relevant
  portion of the `.nextflow.log` or process `.command.log`.
- Minimal configuration to reproduce the issue, if possible.

## Development setup

```bash
git clone https://github.com/bahlolab/nf-cavalier.git
cd nf-cavalier
```

The pipeline uses containers for all tool dependencies — no additional local
installations are needed beyond Nextflow ≥ 24.04 and a container runtime
(Docker / Singularity / Apptainer).

For interactive development, run the end-to-end CEPH trio test dataset on chr22:

```bash
# One-time: download chr22 inputs
bash tests/ceph_trio/download.sh

# Run with the test config
nextflow run . -resume -c tests/ceph_trio/test_ceph_trio.config
```

See [docs/test_dataset.md](docs/test_dataset.md) for full instructions.

## Code conventions

Match the patterns already used in the codebase.

### Nextflow modules

- One process per file in `modules/local/`, named `<tool>.nf` (snake_case).
- Process names are `UPPERCASE` (e.g. `VEP`, `SCATTER`).
- Every process opens with a short comment block describing its purpose and carries a `tag`.
- Resource labels follow the `C<n>M<m>T<h>` scheme (e.g. `label 'C4M8T8'` = 4 CPUs,
  8 GB RAM, 8 h). Labels are mapped to actual limits in [nextflow.config](nextflow.config).
- Container labels are tool names (`label 'vep'`), also mapped in
  [nextflow.config](nextflow.config) — never hard-code image URIs in modules.
- Do not redefine `errorStrategy`, `maxRetries`, or `process.shell` — global defaults in
  [nextflow.config](nextflow.config) already cover these.
- Channel elements use `tuple val(id), path(files)`. Construct channels via helpers in
  [functions/channels.nf](functions/channels.nf).

### Configuration

All parameters belong in [nextflow.config](nextflow.config) and must be documented in
[nextflow_schema.json](nextflow_schema.json) (used by parameter validation).
Profile-specific paths (e.g. Bahlolab annotation cache) go in [profiles.config](profiles.config).

### Scripts (`bin/`)

- R scripts follow tidyverse style.
- Keep scripts self-contained — dependencies are provided by the process container, not
  installed at runtime.

## Submitting changes

1. Fork the repository and create a branch from `master`.
2. Make your changes following the conventions above.
3. Verify the end-to-end test dataset passes (`tests/ceph_trio/`).
4. Open a pull request against `master` with a description of what changed and why.

### Changelog

Add a brief entry to [CHANGELOG.md](CHANGELOG.md) under the appropriate section
(`Added`, `Changed`, `Fixed`) following the
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format. Do not bump the
version — the maintainers will handle releases.

## Versioning

Releases use a `YY.MM.patch` scheme (e.g. `26.06.0`). Releases are tagged in GitHub
and accompanied by a `CHANGELOG.md` entry written by the maintainers.

## Contact

For questions not suited to a GitHub issue, reach out to the maintainers:

- Jacob Munro ([@jemunro](https://github.com/jemunro)) — munro.j@wehi.edu.au
