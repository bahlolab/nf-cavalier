
process PDF_SPLIT {
    label 'C2M2T2'
    label 'qpdf'
    tag "$fam"
    publishDir "${params.outdir}/by_family/$fam", mode: 'copy'
    /*
        - Speparate sample PDFs into individual genes, to by compiled by gene
    */

    input:
    tuple val(fam), path(pdf)

    output:
    path("varslides/*.pdf"), optional: true

    script:
    """
    mkdir -p varslides

    qpdf --json --json-key=outlines $pdf \\
      | awk '
        /"title":/ {
          ++p
          line=\$0

          if (line ~ /:[[:space:]]*[^[:space:]]+[[:space:]]*-[[:space:]]*chr/) {
            sub(/.*:[[:space:]]*/, "", line)

            match(line, /chr([0-9]+|[XY])-[^[:space:]]+/)
            variant=substr(line, RSTART, RLENGTH)
            gsub(/[",]+\$/, "", variant)

            sub(/[[:space:]]*-[[:space:]]*chr.*/, "", line)
            gene=toupper(line)

            key = "__" gene "__." variant
            if (!(key in seen)) { seen[key]=1; order[++n]=key }
            k = ++cnt[key]
            page[key, k] = p
          }
        }

        END {
          for (i=1; i<=n; i++) {
            key = order[i]
            s = ""
            for (j=1; j<=cnt[key]; j++) {
              if (j>1) s = s ","
              s = s page[key, j]
            }
            print "qpdf --empty --pages \\"$pdf\\" " s " -- \\"varslides/${fam}." key ".pdf\\""
          }
        }
      ' \\
      | xargs -P ${task.cpus} -I{} bash -lc '{}'
    """
}