#!/usr/bin/awk -f
# Convert a UCSC genePred TSV (e.g. ncbiRefSeqSelect, the same file SVPV uses via
# -ref_gene) into GFF3 feature rows on stdout, for samplot's -T option (caller
# prepends the ##gff-version 3 header, then sorts, bgzips and tabix-indexes).
#
# samplot's parser keys genes by `Name`, links transcripts to genes via the gene's
# `ID` (transcript `Parent` == gene `ID`), reads the transcript label from the mRNA's
# `Name`, and groups CDS by the mRNA `ID` (CDS `Parent` == mRNA `ID`). So we emit:
#   gene  ID=<symbol>;Name=<symbol>
#   mRNA  ID=<accession>;Name=<symbol>;Parent=<symbol>
#   CDS   ID=<accession>.cds;Parent=<accession>   (exons clipped to CDS range)
#
# Usage: genepred_to_gff3.awk <genePred.tsv>

BEGIN { FS = OFS = "\t" }

# Detect leading bin column (UCSC database tables have it): the chrom column
# starts with "chr". o = field offset (1 if bin present, else 0).
{
    if ($3 ~ /^chr/)      o = 1
    else if ($2 ~ /^chr/) o = 0
    else next

    name    = $(1+o)
    chrom   = $(2+o)
    strand  = $(3+o)
    txS     = $(4+o)
    txE     = $(5+o)
    cdsS    = $(6+o)
    cdsE    = $(7+o)
    eStarts = $(9+o)
    eEnds   = $(10+o)
    symbol  = $(12+o)

    if (symbol == "" || symbol == ".") symbol = name

    # gene + mRNA span the full transcript (GFF3 is 1-based inclusive)
    print chrom, "ncbiRefSeqSelect", "gene", txS+1, txE, ".", strand, ".", "ID=" symbol ";Name=" symbol
    print chrom, "ncbiRefSeqSelect", "mRNA", txS+1, txE, ".", strand, ".", "ID=" name ";Name=" symbol ";Parent=" symbol

    # CDS: clip each exon to [cdsS, cdsE]; skip non-coding (cdsS == cdsE)
    if (cdsS < cdsE) {
        n = split(eStarts, es, ",")
        split(eEnds, ee, ",")
        for (i = 1; i <= n; i++) {
            if (es[i] == "") continue
            lo = es[i] > cdsS ? es[i] : cdsS
            hi = ee[i] < cdsE ? ee[i] : cdsE
            if (lo < hi)
                print chrom, "ncbiRefSeqSelect", "CDS", lo+1, hi, ".", strand, ".", "ID=" name ".cds;Parent=" name
        }
    }
}
