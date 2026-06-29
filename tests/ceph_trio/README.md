# 1000G CEPH trio test dataset

An end-to-end example for nf-cavalier (CEPH trio NA12878 / NA12891 /
NA12892, chr22). The inputs in this directory are produced by
[`download.sh`](download.sh).

See **[docs/test_dataset.md](../../docs/test_dataset.md)** for the full guide:
data sources, prerequisites, how to prepare the inputs, and how to run.

Quick start (from the repository root):

```bash
bash tests/ceph_trio/download.sh -r /path/to/Homo_sapiens_assembly38.fasta
nextflow run . -c tests/ceph_trio/test_ceph_trio.config -resume
```
