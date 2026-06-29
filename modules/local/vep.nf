
include { spliceai_enabled  } from '../../functions/vep_helpers'
include { alphamiss_enabled } from '../../functions/vep_helpers'
include { revel_enabled     } from '../../functions/vep_helpers'
include { utr_ann_enabled   } from '../../functions/vep_helpers'
include { get_vep_fields    } from '../../functions/vep_helpers'

process VEP {
    label 'C4M8T8'
    label 'vep'
    tag "$i"
    /*
        - Run VEP with various plugins to annotation SNV/indel variants
        - Optionally check no variants are being dropped
    */

    input:
        tuple val(i), path(vcf_input)
        tuple path(fasta), path(fai)
        path(vep_cache)
        tuple path(spliceai_snv), path(spliceai_snvindex), path(spliceai_indel), path(spliceai_indel_index)
        tuple path(alphamiss), path(alphamiss_index)
        tuple path(revel), path(revel_index)
        path(utr_annotator)
        val(vep_fields)

    output:
        path(output)

    script:
    output = vcf_input.name.replaceAll('.vcf.gz', '.vep.vcf.gz')
    
    check_block = params.vep_check ?
        """
        bgzip -dc $vcf_input | grep -v '^#' | wc -l > NIN.txt &
        bgzip -dc $output    | grep -v '^#' | wc -l > NOUT.txt
        wait; NIN=\$(<NIN.txt); NOUT=\$(<NOUT.txt)
        if [[ "\$NIN" != "\$NOUT" ]]; then
            echo "Error: Number of input variants (\$NIN) not equal to number of output variants (\$NOUT)"
            exit 1
        fi
        """ :
        ''

    """
    bgzip -dc $vcf_input \\
        | vep \\
            --input_file STDIN \\
            --format vcf \\
            --vcf \\
            --fork $task.cpus \\
            --offline \\
            --dir_plugins /usr/local/share/ensembl-vep-114.0-0 \\
            --cache \\
            --cache_version $params.vep_cache_ver \\
            --dir $vep_cache \\
            --assembly GRCh38 \\
            --fasta $fasta \\
            --pick_allele_gene \\
            --check_existing \\
            --hgvs \\
            --hgvsg \\
            --symbol \\
            --numbers \\
            --protein \\
            --no_stats \\
            --no_intergenic \\
            --variant_class \\
            --dont_skip \\
            --sift b \\
            --polyphen b \\
            --fields "${vep_fields.join(',')}" \\
            ${spliceai_enabled()  ? "--plugin SpliceAI,snv=$spliceai_snv,indel=$spliceai_indel" : ''} \\
            ${alphamiss_enabled() ? "--plugin AlphaMissense,file=$alphamiss,transcript_match=1" : ''} \\
            ${revel_enabled()     ? "--plugin REVEL,file=$revel" : ''} \\
            ${utr_ann_enabled()   ? "--plugin UTRAnnotator,file=$utr_annotator" : ''} \\
            --output_file STDOUT \\
        | bgzip -c > $output

    $check_block
    """
}


process VEP_STRUC {
    label 'C4M8T8'
    label 'vep'
    tag "$i"
    /*
        - Run VEP on structural variants
        - Optionally check no variants are being dropped
    */

    input:
        tuple val(i), path(vcf_input)
        tuple path(fasta), path(fai)
        path(vep_cache)
        val(vep_fields)

    output:
        path(output)

    script:
    output = vcf_input.name.replaceAll('.vcf.gz', '.vep.vcf.gz')
    
    check_block = params.vep_check ?
        """
        bgzip -dc $vcf_input | grep -v '^#' | wc -l > NIN.txt &
        bgzip -dc $output    | grep -v '^#' | wc -l > NOUT.txt
        wait; NIN=\$(<NIN.txt); NOUT=\$(<NOUT.txt)
        if [[ "\$NIN" != "\$NOUT" ]]; then
            echo "Error: Number of input variants (\$NIN) not equal to number of output variants (\$NOUT)"
            exit 1
        fi
        """ :
        ''

    """
    bgzip -dc $vcf_input \\
        | vep \\
            --input_file STDIN \\
            --format vcf \\
            --vcf \\
            --fork $task.cpus \\
            --offline \\
            --cache \\
            --cache_version $params.vep_cache_ver \\
            --dir $vep_cache \\
            --assembly GRCh38 \\
            --fasta $fasta \\
            --pick_allele_gene \\
            --check_existing \\
            --hgvs \\
            --hgvsg \\
            --symbol \\
            --numbers \\
            --protein \\
            --no_stats \\
            --no_intergenic \\
            --variant_class \\
            --dont_skip \\
            --fields "${vep_fields.join(',')}" \\
            --output_file STDOUT \\
        | bgzip -c > $output

    $check_block
    """
}

