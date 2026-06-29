
process REF_GENE_GFF3 {
    label 'C2M4T4'
    label 'bcftools'
    storeDir "${params.cavalier_cache_dir}/store"


    /*
        - Convert the UCSC ncbiRefSeqSelect genePred TSV (same file SVPV uses via
          -ref_gene) into a sorted, bgzipped, tabix-indexed GFF3 for samplot's
          -T/--transcript_file option.
        - samplot's parser only reads `gene` / `mRNA` / `CDS` rows and keys genes by
          `Name`, linking transcripts via `Parent`, so we emit:
            gene  ID=<symbol>;Name=<symbol>
            mRNA  ID=<accession>;Parent=<symbol>
            CDS   ID=<accession>.cds;Parent=<accession>   (exons clipped to CDS range)
    */

    input:
    path ref_gene

    output:
    path "ncbiRefSeqSelect.gff3.gz*"

    script:
    """
    {
        echo "##gff-version 3"
        genepred_to_gff3.awk $ref_gene | sort -k1,1 -k4,4n
    } | bgzip > ncbiRefSeqSelect.gff3.gz
    tabix -p gff ncbiRefSeqSelect.gff3.gz
    """
}
