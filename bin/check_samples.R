#!/usr/bin/env Rscript

stopifnot(
  require(tidyverse),
  require(cavalier)
)

# set command line arguments
args      <- commandArgs(trailingOnly = TRUE)
short_vcf <- args[1]
struc_vcf <- args[2]
in_bam    <- args[3]
out_bam   <- args[4]
in_ped    <- args[5]
out_ped   <- args[6]

Sys.setenv("VROOM_CONNECTION_SIZE" = 1048576)

bams <- 
  read_tsv(
    in_bam, 
    col_names = c("sample_id", "bam_path"), 
    show_col_types = FALSE
  ) %>%
  distinct()

bam_ids <- bams$sample_id

if (length(bam_ids) > length(unique(bam_ids))) {
  stop("✖ Duplicated sample IDs in input bam manifest\n")
}

message('\nℹ Found ', length(bam_ids), ' samples in bam manifest')

if (in_ped == 'UNSET') {
  message('\nℹGenerating uninformative pedigree based on bam manifest')
  # generate uniformative pedigree
  pedigree <- 
    tibble(
      fid = bam_ids,
      iid = bam_ids,
      pid = '0',
      mid = '0',
      sex = '0',
      phe = '2'
    )
} else {
  invisible(cavalier::read_ped(in_ped)) # just checking errors
  pedigree <- 
    read_tsv(
      in_ped, 
      col_names = c("fid", "iid", 'pid', 'mid', 'sex', 'phe'), 
      col_types = cols(.default = col_character())
    ) %>%
    distinct()
  
  message('\nℹ Found ', length(pedigree$iid), ' samples in pedigree')
}

if (short_vcf != "UNSET") {
  
  short_vcf_ids <- read_lines(short_vcf)
  message('\nℹ Found ', length(short_vcf_ids), ' samples in short  VCF')
  
} else {
  short_vcf_ids <- bam_ids
  message("\nℹ No short VCF file provided")
}

if (struc_vcf != "UNSET") {
  
  struc_vcf_ids <- read_lines(struc_vcf)
  message('\nℹ Found ', length(struc_vcf_ids), ' samples in struc  VCF')
  
} else {
  struc_vcf_ids <- bam_ids
  message("\nℹ No struc VCF file provided")
}

ISEC  <- intersect(bam_ids, pedigree$iid) %>% intersect(short_vcf_ids) %>% intersect(struc_vcf_ids)
UNION <- unique(c(bam_ids, pedigree$iid, short_vcf_ids, struc_vcf_ids))

if (length(UNION) == 0) {
  stop("✖ No sample IDs in union of inputs\n")
}
if (length(UNION) < length(ISEC)) {
  warning(
    "⚠ Intersection of sample IDs is smaller than union:\n\t",
    "|union| = ", length(UNION), "\n\t",
    "|intersection| = ", length(ISEC), "\n",
    "Using intersection ..."
  )
} else {
  message('✔ All input samples sets match')
}

bams %>% 
  filter(sample_id %in% ISEC) %>% 
  write_tsv(out_bam, col_names = F)

ped_flt <-
  pedigree %>% 
  group_by(fid) %>% 
  filter(any(iid %in% ISEC)) %>% 
  ungroup() %>% 
  write_tsv(out_ped, col_names = F)

file.create("warnings.txt")

if (length(bam_ids) > length(ISEC)) {
  str_c("Dropped ", length(bam_ids) - length(ISEC), ' sample(s) from bam manifest missing from intersection') %>% 
    write_lines('warnings.txt', append = T)
}

fams <- unique(pedigree$fid)
fams_flt <- unique(ped_flt$fid)
if (length(fams) > length(fams_flt) & in_ped != 'UNSET') {
  str_c("Dropped ", length(fams) - length(fams_flt), ' families(s) from pedigree missing from intersection') %>% 
    write_lines('warnings.txt', append = T)
}

if (length(short_vcf_ids) > length(ISEC) & short_vcf != 'UNSET') {
  str_c("Dropped ", length(short_vcf_ids) - length(ISEC), ' samples(s) from short VCF missing from intersection') %>% 
    write_lines('warnings.txt', append = T)
}

if (length(struc_vcf_ids) > length(ISEC) & struc_vcf != 'UNSET') {
  str_c("Dropped ", length(struc_vcf_ids) - length(ISEC), ' samples(s) from struc VCF missing from intersection') %>% 
    write_lines('warnings.txt', append = T)
}




