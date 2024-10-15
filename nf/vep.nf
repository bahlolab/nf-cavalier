params.vep_output_opts = [
    '--sift b',
    '--polyphen b',
    '--ccds',
    '--hgvs',
    '--hgvsg',
    '--symbol',
    '--numbers',
    '--protein',
    // '--biotype',
    '--af',
    '--af_1kg',
    '--af_gnomad',
    // '--af_gnomade',
    // '--af_gnomadg',
    '--max_af',
    '--variant_class'
].join(' ')

params.vep_filter_opts = [
    '--pick_allele_gene',
    '--no_intergenic',
    '--dont_skip'
].join(' ')


process vep {
    label 'C4M8T2'
    tag { "$set:$i:$j" }

    input:
        tuple val(set), val(i), val(j), path(bcf), path(fasta), path(fai), path(cache)

    output:
        tuple val(set), path(vep_bcf)

    script:
        vep_bcf = bcf.name.replaceAll('.bcf', '.vep.bcf')
    
    """
    bcftools view --no-version $bcf |
        vep --input_file STDIN \\
            $params.vep_output_opts \\
            $params.vep_filter_opts \\
            --fork $task.cpus \\
            --format vcf \\
            --vcf \\
            --cache \\
            --offline \\
            --no_stats \\
            --fasta $fasta \\
            --assembly $params.vep_assembly \\
            --cache_version $params.vep_cache_ver \\
            --dir $cache \\
            --output_file STDOUT |
        bcftools view --no-version -Ob -o $vep_bcf
    
    NIN=\$(bcftools view --threads $task.cpus -H $bcf | wc -l)
    NOUT=\$(bcftools view --threads $task.cpus -H $vep_bcf | wc -l)
    if [[ "\$NIN" != "\$NOUT" ]]; then
        echo "Error: Number of input variants (\$NIN) not equal to number of output variants (\$NOUT)"
        exit 1
    fi
    """
}


process vep_sv {
    label 'C4M8T2'
    tag { "$set:$i:$j" }

    input:
        tuple val(set), val(i), val(j), path(bcf), path(pop_sv), path(pop_sv_tbi), path(fasta), path(fai), path(cache)

    output:
        tuple val(set), path(vep_bcf)

    script:
    vep_bcf = bcf.name.replaceAll(/(\.vcf\.gz)|(\.bcf)$/, '.vep.bcf')
    """
    bcftools view --no-version  $bcf |
        vep --input_file STDIN \\
            $params.vep_output_opts \\
            $params.vep_filter_opts \\
            --fork $task.cpus \\
            --format vcf \\
            --vcf \\
            --plugin StructuralVariantOverlap,reciprocal=1,file=$pop_sv,cols=AF:SVTYPE:END,label=SVO \\
            --cache \\
            --offline \\
            --no_stats \\
            --fasta $fasta \\
            --assembly $params.vep_assembly \\
            --cache_version $params.vep_cache_ver \\
            --dir $cache \\
            --output_file STDOUT |
        bcftools view --no-version -i "INFO/CSQ ~ '.'" -Ob -o $vep_bcf
    
    NIN=\$(bcftools view --threads $task.cpus -H $bcf | wc -l)
    NLONG=\$( (grep 'too long to annotate\\|looks incomplete' STDOUT_warnings.txt ||:) | wc -l )
    NIN=\$((NIN - NLONG))
    NOUT=\$(bcftools view --threads $task.cpus -H $vep_bcf | wc -l)
    if [[ "\$NIN" != "\$NOUT" ]]; then
        echo "Error: Number of input variants (\$NIN) not equal to number of output variants (\$NOUT)"
        exit 1
    fi
    """
}
