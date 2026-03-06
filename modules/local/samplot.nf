
process SAMPLOT {
    label 'C2M4T4'
    label 'samplot'
    tag "$fam"
    publishDir "${params.outdir}/by_family/$fam/samplot", mode: 'copy'

    /*
        - Generate samplot for structural variants
    */

    input:
    tuple val(fam), val(sites), val(ids), path(bams), path(bais)
    tuple path(ref), path(ref_fai)

    output:
    tuple val(fam), path("*.png")

    script:
    def cram_flag = bams.any { it.name.endsWith('.cram') } ? "-r $ref" : ""
"""
export MPLCONFIGDIR=\$PWD/mpl_tmp
cat > sites <<< '${sites}'
(
    while IFS=\$'\\t' read -r NAME CHROM START END TYPE; do

    window_flag=""
    if [[ "\$TYPE" == "INS" && "\$START" == "\$END" ]]; then
        window_flag="-w 1000"
    fi

        echo "samplot plot \\
            -n ${ids.join(' ')} \\
            -b ${bams.join(' ')} \\
            -o ${fam}.\$NAME.png \\
            -c \$CHROM \\
            -s \$START \\
            -e \$END \\
            -t \$TYPE \\
            ${cram_flag} \\
            \$window_flag"
    done < sites
) | xargs -n 1 -P ${task.cpus} -I {} sh -c '{}'
"""
}