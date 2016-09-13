//setup
params.extract_variants_path="/home/jesperei/assemblatron_test/FindSV/TIDDIT/variant_assembly_filter/extract_variants.py"
params.assemble_variants_path="/home/jesperei/assemblatron_test/FindSV/TIDDIT/variant_assembly_filter/assemble_variants.py"
params.update_vcf_path="/home/jesperei/assemblatron_test/FindSV/TIDDIT/variant_assembly_filter/update_TIDDIT_vcf.py"
//----##----

params.bam="none"
bam_file = file(params.bam)
if(!bam_file.exists()) exit 1, "Missing bam file; please specify --bam <BAM_FILE> --working_dir <WORKING_DIR> --genome <REFERENCE_FASTA> --vcf <VCF>"
params.index = params.bam.replaceFirst(/.bam/,".bam.bai")
bam_index=file(params.index)
if(!bam_index.exists()){
    bam_index = file(params.bam.replaceFirst(/.bam/,".bai"))
}

params.vcf="none"
vcf_file = file(params.vcf)
if(!vcf_file.exists()) exit 1, "Missing vcf file; please specify --bam <BAM_FILE> --working_dir <WORKING_DIR> --genome <REFERENCE_FASTA> --vcf <VCF>"
vcf_output= params.vcf.replaceFirst(/.vcf/,"_assemblator.vcf")

params.genome="none"
genome_file = file(params.genome)
if(!genome_file.exists()) exit 1, "Missing reference fasta file; please specify --bam <BAM_FILE> --working_dir <WORKING_DIR> --genome <REFERENCE_FASTA> --vcf <VCF>"


params.working_dir="assemblatron"

//First extract the variants into bam separate bam files
process extract_variants {

    input:
    file vcf_file
    file bam_file
    file bam_index

    output:
    file "${params.working_dir}/*.bam" into extracted_bams mode flatten

    script:
    """
    python ${params.extract_variants_path} --vcf ${vcf_file} --bam ${bam_file} --working_dir ${params.working_dir}
    """
}

//Then assemble the variants
process assemble_variants {
    time "20m"

    input:
    file variant from extracted_bams
    
    output:
    file "${variant.baseName}.fa" into fa_files
    
    script:
    """
    python ${params.assemble_variants_path} --fa ${params.genome} --bam ${variant} --t 1
    """
}

//Then assemble the variants
process align_variants {
    validExitStatus 0,137
    time "20m"


    input:
    file variant from fa_files

    output:
    file "${variant.baseName}.sam" into sam_files

    script:
    """
    bwa bwasw  -C ${params.genome} ${variant} > ${variant.baseName}.sam
    """
}

  
//lastly update the vcf file
process update_variants {
    publishDir "${params.working_dir}"

    input:
    file vcf_file
    file sam_file from sam_files.toList()
    output:
    file "assemblator.vcf" into assemblator_vcf    
    script:
    """
     mkdir ${params.working_dir}
     mv *.sam ${params.working_dir}
    
     python ${params.update_vcf_path} --vcf ${vcf_file} --working_dir ${params.working_dir} > assemblator.vcf
    """
}
