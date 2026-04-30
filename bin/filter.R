#!/usr/bin/env Rscript

stopifnot(
  require(tidyverse),
  require(magrittr),
  require(docopt),
  require(cavalier)
)

MAIN <- function(opts) {
  
  message('Using CLI options:')
  PRINT_STR(
    opts[str_detect(names(opts), '^[:alpha:]')] 
  )

  ############### SET OPTIONS ######################
  do.call(options, jsonlite::fromJSON(opts$options))
  message('Using filter options:')
  PRINT_STR(
    options() %>% {.[str_starts(names(.), 'FILTER_')]}
  )
  if (!is.null(opts$cav_opts)) {
    cavalier::set_options_from_json(opts$cav_opts)
  }
  
  ################# CHECK ARGS ######################
  stopifnot(
    !is.null(opts$short_var) || !is.null(opts$struc_var),
    is.null(opts$short_var)  || file.exists(opts$short_var),
    is.null(opts$struc_var)  || file.exists(opts$struc_var),
    file.exists(opts$ped),
    file.exists(opts$gene_set)
  )
  
  ############## READ PEDIGREE   ################
  
  pedigree <- cavalier::read_ped(opts$ped)
  
  ##############  GENE LIST ###############
  gene_set <- unique(na.omit(read_lines(opts$gene_set)))
  message('Searching for variants in ', length(gene_set), ' genes')
  
  ########## SHORT VARS #################
  short_cand <- NULL
  if (!is.null(opts$short_var)) {
    short_cand <- LOAD_AND_FILTER_SHORT(
      short_var = opts$short_var, 
      gene_set = gene_set,
      pedigree = pedigree
    )
  }
  
  ######### STRUC VARS #################
  struc_cand <- NULL
  if (!is.null(opts$struc_var)) {
    struc_cand <- LOAD_AND_FILTER_STRUC(
      struc_var = opts$struc_var, 
      gene_set = gene_set,
      pedigree = pedigree
    )
  }
  
  ########## COMPOUND FILTER(BOTH) ################
  
  FC <- FILTER_COMPOUND(SHORT_VAR = short_cand, STRUC_VAR = struc_cand)
  
  ######### OUTPUTS ###############################

  if (!is.null(FC$SHORT)) {
    
    saveRDS(FC$SHORT, str_c(opts$output, '.short.filtered_variants.rds'))
    
    FC$SHORT %>%
      select(where(~ !is.data.frame(.))) %>%
      pivot_longer(
        cols = starts_with("FMT_"),
        names_to = c(".value", "sample_id"),
        names_pattern = "(FMT_[^_]+)_(.*)"
      ) %>%
      mutate(across(starts_with("FMT_"), ~ paste0(sample_id, ":", .x))) %>%
      select(-sample_id) %>%
      chop(starts_with("FMT_")) %>%
      mutate(across(starts_with("FMT_"), ~ map_chr(., ~ str_c(.x, collapse = ";")))) %>%
      mutate(family_id = pedigree$famid[1], .before = 1) %>%
      write_csv(
        file = str_c(opts$output, '.short.filtered_variants.csv')
      )
    
    write_csv(
      .GlobalEnv$.tracking.SHORT$filtered,
      file = str_c(opts$output, '.short.reason_filtered.csv.gz')
    )

    PLOT_FILTERING(
      n_pass = nrow(FC$SHORT),
      filtered = .GlobalEnv$.tracking.SHORT$filtered,
      output = str_c(opts$output, '.short.filtering')
    )
    
    FC$SHORT %>% 
      transmute(
        CHROM = CHROM, 
        START = POS - 1L,
        END = START + if_else(nchar(ALT) > nchar(REF), 2L, nchar(ALT)),
        title = variant_id,
      ) %>% 
      distinct() %>% 
      write_tsv(
        str_c(opts$output, '.short.igv.bed'),
        col_names = F
      )

    cat(nrow(FC$SHORT), file = str_c(opts$output, '.short.count'))
    
  } else {
    cat("0", file = str_c(opts$output, '.short.count'))
  }
  
  if (!is.null(FC$STRUC)) {
    
    saveRDS(FC$STRUC, str_c(opts$output, '.struc.filtered_variants.rds'))
    
    FC$STRUC %>% 
      select(where(~ !is.data.frame(.))) %>% 
      pivot_longer(
        cols = starts_with("FMT_"),
        names_to = c(".value", "sample_id"),
        names_pattern = "(FMT_[^_]+)_(.*)"
      ) %>%
      mutate(across(starts_with("FMT_"), ~ paste0(sample_id, ":", .x))) %>%
      select(-sample_id) %>%
      chop(starts_with("FMT_")) %>%
      mutate(across(starts_with("FMT_"), ~ map_chr(., ~ str_c(.x, collapse = ";")))) %>%
      mutate(family_id = pedigree$famid[1], .before = 1) %>%
      write_csv(
        file = str_c(opts$output, '.struc.filtered_variants.csv')
      )
    
    write_csv(
      .GlobalEnv$.tracking.STRUC$filtered,
      file = str_c(opts$output, '.struc.reason_filtered.csv.gz')
    )

    PLOT_FILTERING(
      n_pass = nrow(FC$STRUC),
      filtered = .GlobalEnv$.tracking.STRUC$filtered,
      output = str_c(opts$output, '.struc.filtering')
    )

    FC$STRUC %>%
      transmute(
        name  = variant_id,
        chrom = CHROM,
        start = POS,
        end   = END,
        type  = SVTYPE,
      ) %>%
      distinct() %>%
      write_tsv(
        str_c(opts$output, ".struc.samplot.tsv"),
        col_names = F
      )
    
    FC$STRUC %>%
      pull(LINE_ID) %>%
      write_lines(str_c(opts$output, ".struc.lines.txt"))

    cat(nrow(FC$STRUC), file = str_c(opts$output, '.struc.count'))

  } else {
    cat("0", file = str_c(opts$output, '.struc.count'))
  }
  
  message('\n----- Filtering complete! ------')
}

############ LOAD_AND_FILTER_SHORT  ###############################
LOAD_AND_FILTER_SHORT <- function(short_var, gene_set, pedigree) {

  message('\n----- Filtering short variants -----')
  
  short_cand <- 
    LOAD_SHORT(short_var) %>% 
    FILTER_SHORT_TYPE() %>% 
    FILTER_SHORT_GENE(gene_set) %>%
    FILTER_INHERITANCE(pedigree, set = "SHORT") %>%
    FILTER_SHORT_FMT()
}

###################### LOAD_SHORT ###############################
LOAD_SHORT <- function(FILEPATH = NULL, ...) {
  # check libraries and args
  stopifnot(
    require(tidyverse),
    rlang::is_scalar_character(FILEPATH),
    file.exists(FILEPATH)
  )
  
  # expected types for columns from default annotation sources
  col_spec <- cols(
    LINE_ID = col_integer(),
    CHROM = col_character(),
    POS = col_integer(),
    REF = col_character(),
    ALT = col_character(),
    AC = col_integer(),
    AF = col_double(),
    AN = col_integer(),
    CADD = col_double(),
    gnomad_AC = col_integer(),
    gnomad_AF = col_double(),
    gnomad_FAF95 = col_double(),
    gnomad_nhomalt = col_integer(),
    phyloP100 = col_double(),
    SYMBOL = col_character(),
    Gene = col_character(),
    VARIANT_CLASS = col_character(),
    Consequence = col_character(),
    IMPACT = col_character(),
    Feature_type = col_character(),
    Feature = col_character(),
    BIOTYPE = col_character(),
    EXON = col_character(),
    INTRON = col_character(),
    HGVSc = col_character(),
    HGVSp = col_character(),
    HGVSg = col_character(),
    Amino_acids = col_character(),
    HGNC_ID = col_character(),
    MANE = col_logical(),
    MANE_SELECT = col_logical(),
    MANE_PLUS_CLINICAL = col_logical(),
    CCDS = col_logical(),
    ENSP = col_character(),
    SIFT = col_character(),
    PolyPhen = col_character(),
    CLNSIG = col_character(),
    CLNGENE = col_character(),
    CLNVID = col_integer(),
    Existing_variation = col_character(),
    am_class = col_character(),
    am_pathogenicity = col_double(),
    promoterAI_gene = col_character(),
    promoterAI = col_character(),
    REVEL = col_double(),
    SpliceAI_pred_DP_AG = col_integer(),
    SpliceAI_pred_DP_AL = col_integer(),
    SpliceAI_pred_DP_DG = col_integer(),
    SpliceAI_pred_DP_DL = col_integer(),
    SpliceAI_pred_DS_AG = col_double(),
    SpliceAI_pred_DS_AL = col_double(),
    SpliceAI_pred_DS_DG = col_double(),
    SpliceAI_pred_DS_DL = col_double(),
    SpliceAI_pred_SYMBOL = col_character(),
    `_5UTR_annotation` = col_character(),
    `_5UTR_consequence` = col_character(),
    Existing_InFrame_oORFs = col_integer(),
    Existing_OutOfFrame_oORFs = col_integer(),
    Existing_uORFs = col_integer(),
    .default = col_character()
  )

  empty <-
    VARIANTS_OUT <-
    # read tsv with custom col_spec
    read_tsv(
      file = FILEPATH,
      na = ".",
      col_types = col_spec,
      show_col_types = FALSE
    ) %>%
    # force all columns to be present
    bind_rows(
      read_delim(file = I(""), col_types = col_spec, col_names = names(col_spec$cols))
    ) %>%
    # try to guess column types not in col_spec, but better to add to col_spec
    readr::type_convert(
      guess_integer = TRUE,
      col_types = col_spec
    ) %>%
    # convert FMT fields to nested data frames
    FMT_TO_DF() %>%
    # add/modify columns
    mutate(
      CLNSIG = if_else(CLNSIG_GENE_MATCH(CLNGENE, SYMBOL, Gene), CLNSIG, NA_character_),
      AN = AN - (GT %>% mutate_all(~ str_count(., "[01]")) %>% rowSums(na.rm = TRUE)),
      AC = AC - (GT %>% mutate_all(~ str_count(., "[1]")) %>% rowSums(na.rm = TRUE)),
      AF = replace_na(AC / AN, 0),
      # useful for filtering
      pop_AF = pmax(replace_na(gnomad_AF, 0), replace_na(gnomad_FAF95, 0)),
      pop_AC = replace_na(gnomad_AC, 0),
      pop_hom = replace_na(gnomad_nhomalt, 0),
      SpliceAI_max =
        replace_na(
          pmax(SpliceAI_pred_DS_AG, SpliceAI_pred_DS_AL, SpliceAI_pred_DS_DG, SpliceAI_pred_DS_DL),
          0
        ),
      SIFT_score = str_extract(SIFT, "(?<=\\()[0-9\\.]+(?=\\)$)") %>% as.numeric(),
      PolyPhen_score = str_extract(PolyPhen, "(?<=\\()[0-9\\.]+(?=\\)$)") %>% as.numeric(),
      # not meaningful for insertions
      phyloP100 = replace(phyloP100, VARIANT_CLASS == "insertion", NA),
      variant_id = str_c(CHROM, POS, REF, ALT, sep = "-")
    ) %>%
    (function(x) {
      left_join(
        select(x, -starts_with("promoterAI")),
        select(x, variant_id, starts_with("promoterAI")) %>%
          separate_rows(promoterAI_gene, promoterAI, sep = ",") %>%
          distinct() %>%
          rename(Gene = promoterAI_gene) %>%
          mutate(promoterAI = as.numeric(promoterAI)),
        by = join_by(variant_id, Gene)
      )
    })
  
  return(
    VARIANTS_OUT %>% TRACK_REASON(init=TRUE)
  )
}

####################### FMT_TO_DF #########################
# helper to convert sample format fields to a dataframe with colnames
FMT_TO_DF <- function(input_data) {
  stopifnot(
    is.data.frame(input_data)
  )
  
  format_fields <- 
    colnames(input_data) %>% 
    keep(str_detect, '^FMT_[A-Za-z]+(?=_)') %>% 
    str_extract('(?<=^FMT_)[A-Za-z]+(?=_)') %>% 
    unique()
  
  output <- input_data
  
  for (FMT in format_fields) {
    prefix <- str_c('FMT_', FMT, '_')
    output <-
      output %>% 
      mutate(
        !!FMT :=
          pick(starts_with(prefix)) %>% 
          rename_with(~ str_remove(., prefix)) %>% 
          {suppressWarnings(
            readr::type_convert(., guess_integer = T, col_types = cols())
          )} 
      )
  }
  
  return(output)
}

#################### CLNSIG_GENE_MATCH #################### 
# helper to restrict ClinVar CLNSIG annotation to matching genes
CLNSIG_GENE_MATCH <- function(CLNGENE, SYMBOL, Gene) {
  # match by symbol
  match1 <- map2_lgl(
    SYMBOL,
    str_extract_all(CLNGENE, '[^|:]+(?=:)'),
    ~ .x %in% .y
  )
  # match by entrez id
  match2 <- map2_lgl(
    as.character(cavalier::hgnc_ensembl2entrez(Gene)), 
    str_extract_all(CLNGENE, '(?<=:)[^|:]+'),
    ~ .x %in% .y
  )
  replace_na(match1 | match2, FALSE)
}

#################### TRACK_REASON #################### 
# keep track of reason variants are removed for debugging
TRACK_REASON <- function(data, reason = NA_character_, init=FALSE, set = 'SHORT') {
  
  force(data)
  
  if (set == 'SHORT') {
    keys = c('LINE_ID', 'CHROM', 'POS', 'REF', 'ALT', 'Gene', 'SYMBOL')
  } else {
    keys = c('LINE_ID', 'CHROM', 'POS', 'SVTYPE', 'SVLEN', 'END', 'Gene', 'SYMBOL')
  }
  env_name <- str_c('.tracking.', set)
  
  if (init) {
    .GlobalEnv[[env_name]] <- new.env()
    env <- .GlobalEnv[[env_name]]
    env$filtered <- tibble()
    env$prev <- data
    env$step <- 0L
    message('Initial ', set, ' Gene-Variants: n=', nrow(data))
  } else {
    env <- .GlobalEnv[[env_name]]
    env$step <- env$step + 1L
    
    new_flt <- 
      select(env$prev, all_of(keys)) %>% 
      anti_join(data, by = keys) %>% 
      mutate(REASON = reason, STEP = env$step) %>% 
      distinct()
    
    env$filtered <-
      bind_rows(
        env$filtered,
        new_flt
      )
    message(reason, ' removed ', nrow(new_flt), ' ', set, ' Gene-Variants, ', nrow(data), ' remain')
    env$prev <- data
  }
  
  return(data)
}

###################### FILTER_SHORT_FMT ###############################
# filter shorts by DP and GQ format fields
FILTER_SHORT_FMT <- function(VARIANTS) {
  stopifnot(
    require(tidyverse),
    is.data.frame(VARIANTS)
  )
  
  VARIANTS_OUT <- VARIANTS 
  
  MIN_DP <- getOption('FILTER_SHORT_MIN_DP')
  if (!is.null(MIN_DP)) {
    stopifnot( 'DP' %in% colnames(VARIANTS) )
    VARIANTS_OUT <-
      VARIANTS_OUT %>% 
      filter(do.call(pmin, unname(DP)) >= MIN_DP)
  }
  
  MIN_GQ <- getOption('FILTER_SHORT_MIN_GQ')
  if (!is.null(MIN_GQ)) {
    stopifnot( 'GQ' %in% colnames(VARIANTS) )
    VARIANTS_OUT <-
      VARIANTS_OUT %>% 
      filter(do.call(pmin, unname(GQ)) >= MIN_GQ)
  }
  
  return(
    VARIANTS_OUT %>% TRACK_REASON('FILTER_SHORT_FMT')
  )
  
}

FILTER_SHORT_GENE <- function(VARIANTS, GENE_SET) {
  stopifnot(
    require(tidyverse),
    is.data.frame(VARIANTS),
    is.character(GENE_SET)
  )
  
  FILTER_SHORT_CLINVAR_LIST_ONLY <- getOption('FILTER_SHORT_CLINVAR_LIST_ONLY', TRUE)
  FILTER_SHORT_CLINVAR_KEEP_PAT <- getOption('FILTER_SHORT_CLINVAR_KEEP_PAT', '$.')
  
  VARIANTS_OUT <-
    VARIANTS %>%
    filter(
      Gene %in% GENE_SET |
        (str_detect(CLNSIG, FILTER_SHORT_CLINVAR_KEEP_PAT) & !FILTER_SHORT_CLINVAR_LIST_ONLY)
    )
  
  return(
    VARIANTS_OUT %>% TRACK_REASON('FILTER_SHORT_GENE')
  )
}

###################### FILTER_SHORT_GENE ###############################
# filter for pressence in certain genes or clinvar pathogenic
FILTER_STRUC_GENE <- function(VARIANTS, GENE_SET, set = 'SHORT') {
  stopifnot(
    require(tidyverse),
    is.data.frame(VARIANTS),
    is.character(GENE_SET)
  )
  
  FILTER_STRUC_LARGE_LENGTH   <- getOption('FILTER_STRUC_LARGE_LENGTH', Inf)
  

  VARIANTS_OUT <-
    VARIANTS %>%
    filter(
      Gene %in% GENE_SET
    )
      
  VARIANTS_OUT <-
    bind_rows(
      VARIANTS_OUT,
      VARIANTS %>% 
        anti_join(VARIANTS_OUT, by = c('LINE_ID')) %>% 
        filter(abs(SVLEN) >= FILTER_STRUC_LARGE_LENGTH) %>% 
        chop(c('SYMBOL', 'Gene', 'Consequence', 'IMPACT', 'Feature', 'BIOTYPE',  'EXON', 'INTRON', 'HGNC_ID',  'ENSP')) %>% 
        mutate(
          Genes   = map_chr(Gene, ~ str_c(unique(sort(na.omit(.))), collapse = '; ')),
          SYMBOLS = map_chr(SYMBOL, ~ str_c(unique(sort(na.omit(.))), collapse = '; ')),
          Gene = 'LARGE_SV',
          SYMBOL = 'LARGE_SV') %>% 
        mutate(across(all_of(c('Consequence', 'IMPACT', 'Feature', 'BIOTYPE',  'EXON', 'INTRON', 'HGNC_ID',  'ENSP')), ~NA_character_))
    )
  
  n_large <- sum(VARIANTS_OUT$Gene == 'LARGE_SV', na.rm = T)
  
  if (n_large) {
    message('FILTER_STRUC_GENE added ', n_large, ' LARGE_SV records')
  }

  return(
    VARIANTS_OUT %>% TRACK_REASON('FILTER_STRUC_GENE', set = 'STRUC')
  )
}

###################### FILTER_SHORT_TYPE ###############################
# Filter short variants by type of interest (i.e. VEP consequence)
FILTER_SHORT_TYPE <- function(VARIANTS) {
  stopifnot(
    require(tidyverse),
    is.data.frame(VARIANTS)
  )
  
  FILTER_SHORT_LOF      <- getOption('FILTER_SHORT_LOF'     , TRUE)
  FILTER_SHORT_MISSENSE <- getOption('FILTER_SHORT_MISSENSE', TRUE)
  FILTER_SHORT_SPLICING <- getOption('FILTER_SHORT_SPLICING', TRUE)
  FILTER_SHORT_PROMOTER <- getOption('FILTER_SHORT_PROMOTER', TRUE)
  FILTER_SHORT_OTHER    <- getOption('FILTER_SHORT_OTHER'   , TRUE)
  
  FILTER_SHORT_CLINVAR_KEEP_PAT <- getOption('FILTER_SHORT_CLINVAR_KEEP_PAT', '$.')
  FILTER_SHORT_CLINVAR_DISC_PAT <- getOption('FILTER_SHORT_CLINVAR_DISC_PAT', '$.')
  
  FILTER_SHORT_VEP_MIN_IMPACT <- 
    getOption('FILTER_SHORT_VEP_MIN_IMPACT', 'MODERATE')
  
  FILTER_SHORT_VEP_IMPACTS <-
    list(
      MODIFIER = c('MODIFIER', 'LOW', 'MODERATE', 'HIGH'),
      LOW = c('LOW', 'MODERATE', 'HIGH'),
      MODERATE = c('MODERATE', 'HIGH'),
      HIGH = c('HIGH')
    )[[FILTER_SHORT_VEP_MIN_IMPACT]]
  
  FILTER_SHORT_VEP_CONSEQUENCES <- 
    getOption('FILTER_SHORT_VEP_CONSEQUENCES', '') %>% 
    str_split(',', simplify = T) %>% 
    c()

  VARIANTS_OUT <-
  VARIANTS %>% 
  filter(!replace_na(str_detect(CLNSIG, FILTER_SHORT_CLINVAR_DISC_PAT), FALSE)) %>% 
  mutate(
    TYPE = case_when(
      ############# SPLICING ########### 
      (
        FILTER_SHORT_SPLICING & 
          (
            SpliceAI_max >= getOption('FILTER_SHORT_MIN_SPLICEAI_PP', -Inf) |
              (
                str_detect(Consequence, "splice") &
                  IMPACT %in% c('MODERATE', 'HIGH')
              ) 
          )
      ) ~ 'SPLICING',
      ############## LOF #############  
      (
        FILTER_SHORT_LOF &
          IMPACT == 'HIGH'
      ) ~ 'LOF',
      ########### MISSENSE ########### 
      (
        FILTER_SHORT_MISSENSE &
          str_detect(Consequence, "missense")
      ) ~ 'MISSENSE',
      (
        FILTER_SHORT_PROMOTER &
          promoterAI <= getOption('FILTER_SHORT_MAX_PROMOTERAI', Inf)
      ) ~ 'PROMOTER',
      ############# OTHER ############# 
      # Captures anything else
      (
        FILTER_SHORT_OTHER &
          (
            IMPACT %in% FILTER_SHORT_VEP_IMPACTS |
              Consequence %in% FILTER_SHORT_VEP_CONSEQUENCES |
              str_detect(CLNSIG, FILTER_SHORT_CLINVAR_KEEP_PAT) |
              CADD > getOption("FILTER_SHORT_MIN_CADD_PP", -Inf)
          )
      ) ~ 'OTHER'
    )
  ) %>% 
  filter(!is.na(TYPE))
   
  return(
    VARIANTS_OUT %>% TRACK_REASON('FILTER_SHORT_TYPE')
  )
}

###################### FILTER_INHERITANCE ###############################
FILTER_INHERITANCE <- function(VARIANTS, PEDIGREE, set = 'SHORT') {
  stopifnot(
    require(tidyverse),
    is.data.frame(VARIANTS),
    is.data.frame(PEDIGREE),
    is.character(set)
  )
  
  pop_dom_max_af  <- getOption(str_c('FILTER_', set, '_POP_DOM_MAX_AF') , Inf)
  pop_rec_max_af  <- getOption(str_c('FILTER_', set, '_POP_REC_MAX_AF') , Inf)
  pop_dom_max_ac  <- getOption(str_c('FILTER_', set, '_POP_DOM_MAX_AC') , Inf)
  pop_rec_max_ac  <- getOption(str_c('FILTER_', set, '_POP_REC_MAX_AC') , Inf)
  pop_dom_max_hom <- getOption(str_c('FILTER_', set, '_POP_DOM_MAX_HOM'), Inf)
  pop_rec_max_hom <- getOption(str_c('FILTER_', set, '_POP_REC_MAX_HOM'), Inf)
  
  coh_dom_max_af  <- getOption(str_c('FILTER_', set, '_COH_DOM_MAX_AF') , Inf)
  coh_rec_max_af  <- getOption(str_c('FILTER_', set, '_COH_REC_MAX_AF') , Inf)
  coh_dom_max_ac  <- getOption(str_c('FILTER_', set, '_COH_DOM_MAX_AC') , Inf)
  coh_rec_max_ac  <- getOption(str_c('FILTER_', set, '_COH_REC_MAX_AC') , Inf)

  FILTER_SHORT_CLINVAR_KEEP_PAT <- getOption('FILTER_SHORT_CLINVAR_KEEP_PAT', '$.')

  VARIANTS_OUT <-
    VARIANTS %>% 
    mutate(
      GENOTYPE = 
        GT %>% 
        mutate_all(function(x) {
          case_when(
            # TODO: HEMI variants? (should just appear as HOM)
            str_count(x, '[01]') == 2 & str_count(x, '[1]') == 2 ~ 'HOM',
            str_count(x, '[01]') == 2 & str_count(x, '[1]') == 1 ~ 'HET',
            str_count(x, '[01]') == 2 & str_count(x, '[1]') == 0 ~ 'REF'
          ) %>% factor(c('REF', 'HET', 'HOM'))
        })
    )
  
  # Affected
  AFF <- 
    filter(PEDIGREE, affected) %>% 
    pull(id) %>% 
    intersect(colnames(VARIANTS_OUT$GENOTYPE))
  # Unaffected
  UNA <- 
    filter(PEDIGREE, !affected) %>% 
    pull(id) %>% 
    intersect(colnames(VARIANTS_OUT$GENOTYPE))
  
  # avoid error for struc vars
  CLNSIG <- NA_character_
  
  VARIANTS_OUT <-
    VARIANTS_OUT %>% 
    mutate(
      inheritance = case_when(
        (
          rowSums(GENOTYPE[, AFF, drop = F] == 'HET') == length(AFF) &
            rowSums(GENOTYPE[, UNA, drop = F] == 'REF') == length(UNA)
        ) ~ 'dominant',
        (
          rowSums(GENOTYPE[, AFF, drop = F] == 'HOM') == length(AFF) &
            rowSums(GENOTYPE[, UNA, drop = F] != 'HOM') == length(UNA)
        ) ~ 'recessive',
      )) %>% 
    select(-GENOTYPE) %>% 
    mutate(
      inheritance = case_when(
         # Retain ClinVar pathogenic regardless of allele frequencies
         
        ( 
          inheritance == 'dominant' &
            pop_AF  <= pop_dom_max_af &
            pop_AC  <= pop_dom_max_ac &
            pop_hom <= pop_dom_max_hom &
            AF      <= coh_dom_max_af &
            AC      <= coh_dom_max_ac 
        ) ~ 'dominant',
        ( 
          inheritance == 'recessive' &
            pop_AF  <= pop_rec_max_af &
            pop_AC  <= pop_rec_max_ac &
            pop_hom <= pop_rec_max_hom &
            AF      <= coh_rec_max_af &
            AC      <= coh_rec_max_ac 
        ) ~ 'recessive',
        ( 
          inheritance == 'dominant' &
            pop_AF  <= pop_rec_max_af &
            pop_AC  <= pop_rec_max_ac &
            pop_hom <= pop_rec_max_hom &
            AF      <= coh_rec_max_af &
            AC      <= coh_rec_max_ac 
        ) ~ 'compound',
        (
          inheritance == 'dominant' &
            str_detect(CLNSIG, FILTER_SHORT_CLINVAR_KEEP_PAT)
        ) ~ 'dominant',
        (
          inheritance == 'recessive' &
            str_detect(CLNSIG, FILTER_SHORT_CLINVAR_KEEP_PAT)
        ) ~ 'recessive',
      )
    ) %>% 
    filter(!is.na(inheritance))
  
  return(
    VARIANTS_OUT %>% TRACK_REASON(str_c('FILTER_INHERITANCE(', set, ')'), set = set)
  )
}

###################### FILTER_COMPOUND ###############################
FILTER_COMPOUND <- function(SHORT_VAR = NULL, STRUC_VAR = NULL) {
  stopifnot(
    require(tidyverse),
    is.data.frame(SHORT_VAR) | is.null(SHORT_VAR),
    is.data.frame(STRUC_VAR) | is.null(STRUC_VAR)
  )
  
  message('----- Filtering compound variants -----')
  
  GENES <- character()
  
  if (!is.null(SHORT_VAR)) {
    GENES <- c(GENES, SHORT_VAR$Gene)
  }
  
  if (!is.null(STRUC_VAR)) {
    GENES <- c(GENES, STRUC_VAR$Gene)
  }
  
  # genes with multiple hits
  GENES <-
    tibble(GENES) %>% 
    count(GENES, name = 'n_hit') %>% 
    filter(n_hit > 1) %>% 
    pull(GENES)

  if (!is.null(SHORT_VAR)) {
    FILTER_SHORT_CLINVAR_KEEP_PAT <- getOption('FILTER_SHORT_CLINVAR_KEEP_PAT', '$.')

    SHORT_OUT <-
      SHORT_VAR %>% 
      filter(
        inheritance != 'compound' | 
          Gene %in% GENES | 
          str_detect(CLNSIG, FILTER_SHORT_CLINVAR_KEEP_PAT)
      ) %>% 
      mutate(inheritance = if_else(
        inheritance == 'dominant' & Gene %in% GENES,
        'dominant/compound',
        inheritance
      )) %>% 
      mutate(inheritance = if_else(
        inheritance == 'compound' & (!Gene %in% GENES) & str_detect(CLNSIG, FILTER_SHORT_CLINVAR_KEEP_PAT),
        'dominant',
        inheritance
      ))

    TRACK_REASON(SHORT_OUT, str_c('FILTER_COMPOUND(SHORT)'), set = 'SHORT')
  } else {
    SHORT_OUT <- NULL
  }
    
  if (!is.null(STRUC_VAR)) {
    STRUC_OUT <-
      STRUC_VAR %>% 
      filter(
        inheritance != 'compound' | Gene %in% GENES
      ) %>% 
      mutate(inheritance = if_else(
        inheritance == 'dominant' & Gene %in% GENES,
        'dominant/compound',
        inheritance
      ))
    TRACK_REASON(STRUC_OUT, str_c('FILTER_COMPOUND(STRUC)'), set = 'STRUC')
  } else {
    STRUC_OUT <- NULL
  }
    
  return(
    list(SHORT = SHORT_OUT, STRUC = STRUC_OUT)
  )
  
}

############ LOAD_AND_FILTER_SHORT  ###############################
LOAD_AND_FILTER_STRUC <- function(struc_var, gene_set, pedigree) {
  
  message('\n----- Filtering structural variants -----')
  
  struc_cand <- 
    LOAD_STRUC(struc_var) %>% 
    FILTER_STRUC_TYPE() %>% 
    FILTER_STRUC_GENE(gene_set) %>% 
    FILTER_INHERITANCE(pedigree, set = "STRUC")
}

###################### LOAD_SHORT ###############################
LOAD_STRUC <- function(FILEPATH = NULL, ...) {
  # check libraries and args
  stopifnot(
    require(tidyverse),
    rlang::is_scalar_character(FILEPATH),
    file.exists(FILEPATH)
  )
  
  # expected types for columns from default annotation sources
  col_spec <- cols(
    LINE_ID = col_integer(),
    CHROM = col_character(),
    POS = col_double(),
    REF = col_character(),
    ALT = col_character(),
    AC = col_integer(),
    AF = col_double(),
    AN = col_integer(),
    SVTYPE = col_character(),
    SVLEN = col_integer(),
    END = col_integer(),
    Max_AF = col_double(),
    Max_Het = col_double(),
    Max_HomAlt = col_integer(),
    Max_PopMax_AF = col_double(),
    ThousG_Count = col_integer(),
    gnomAD_Count = col_integer(),
    CCDG_Count = col_integer(),
    TOPMed_Count = col_integer(),
    SYMBOL = col_character(),
    Gene = col_character(),
    VARIANT_CLASS = col_character(),
    Consequence = col_character(),
    IMPACT = col_character(),
    Feature_type = col_character(),
    Feature = col_character(),
    BIOTYPE = col_character(),
    EXON = col_character(),
    INTRON = col_character(),
    HGVSc = col_logical(),
    HGVSp = col_logical(),
    HGVSg = col_logical(),
    Amino_acids = col_logical(),
    HGNC_ID = col_character(),
    MANE = col_logical(),
    MANE_SELECT = col_logical(),
    MANE_PLUS_CLINICAL = col_logical(),
    CCDS = col_logical(),
    ENSP = col_character(),
    Existing_variation = col_logical(),
    .default = col_character()
  )
  
  VARIANTS_OUT <-
    # read tsv with custom col_spec
    read_tsv(
      file = FILEPATH,
      na = ".",
      col_types = col_spec,
      show_col_types = FALSE
    ) %>%
    bind_rows(
      read_delim(file = I(""), col_types = col_spec, col_names = names(col_spec$cols))
    ) %>%
    # try to guess column types not in col_spec, but better to add to col_spec
    readr::type_convert(
      guess_integer = TRUE,
      col_types = col_spec
    ) %>% 
    # convert FMT fields to nested data frames
    FMT_TO_DF() %>%
    # add/modify columns
    mutate(
      AN = AN - (GT %>% mutate_all(~ str_count(., '[01]')) %>% rowSums(na.rm = TRUE)),
      AC = AC - (GT %>% mutate_all(~ str_count(., '[1]')) %>% rowSums(na.rm = TRUE)),
      AF = replace_na(AC / AN, 0),
      # useful for filtering
      pop_AF =  replace_na(Max_AF, 0),
      pop_AC =  -1L,
      pop_hom = replace_na(Max_HomAlt, 0),
      variant_id = str_c(CHROM, POS, SVTYPE, replace_na(as.character(abs(SVLEN)), '_'), sep = '-')
      # TODO: variant_id is not strictly unique - include line number too ?
    )
  
  return(
    VARIANTS_OUT %>% TRACK_REASON(init=TRUE, set = 'STRUC')
  )
}

###################### FILTER_SHORT_TYPE ###############################
# Filter short variants by type of interest (i.e. VEP consequence)
FILTER_STRUC_TYPE <- function(VARIANTS) {
  stopifnot(
    require(tidyverse),
    is.data.frame(VARIANTS)
  )
  
  FILTER_STRUC_VEP_MIN_IMPACT <- getOption('FILTER_STRUC_VEP_MIN_IMPACT', 'MODERATE')
  FILTER_STRUC_LARGE_LENGTH   <- getOption('FILTER_STRUC_LARGE_LENGTH', Inf)
  
  FILTER_STRUC_VEP_CONSEQUENCES <- 
    getOption('FILTER_STRUC_VEP_CONSEQUENCES', character()) %>% 
    str_split(',', simplify = T) %>% 
    c()
  
  FILTER_STRUC_SVTYPES <- 
    getOption('FILTER_STRUC_SVTYPES', 'DEL,DUP,INS,INV,BND') %>% 
    str_split(',', simplify = T) %>% 
    c()
  
  FILTER_STRUC_VEP_IMPACTS <-
    list(
      MODIFIER = c('MODIFIER', 'LOW', 'MODERATE', 'HIGH'),
      LOW = c('LOW', 'MODERATE', 'HIGH'),
      MODERATE = c('MODERATE', 'HIGH'),
      HIGH = c('HIGH')
    )[[FILTER_STRUC_VEP_MIN_IMPACT]]

  VARIANTS_OUT <-
    VARIANTS %>% 
    filter(SVTYPE %in% FILTER_STRUC_SVTYPES) %>% 
    filter(
      IMPACT %in% FILTER_STRUC_VEP_IMPACTS |
      str_split(Consequence, "&") %>% map_lgl(~ any(. %in% FILTER_STRUC_VEP_CONSEQUENCES)) |
      abs(SVLEN) >= FILTER_STRUC_LARGE_LENGTH
    ) %>% 
    mutate(TYPE = SVTYPE)
  
  return(
    VARIANTS_OUT %>% TRACK_REASON('FILTER_STRUC_TYPE', set = 'STRUC')
  )
}

PLOT_FILTERING <- function(n_pass, filtered, output, title = 'Variant filtering') {
  n_init <- n_pass + nrow(filtered)
  
  plot <-
    filtered %>%
    mutate(REASON = REASON %>%
      str_remove_all("FILTER_") %>%
      str_remove_all("\\(?(STRUC|SHORT)\\)?_?")) %>%
    mutate(REASON = case_when(
      REASON == "TYPE" ~ "Type/Impact",
      REASON == "GENE" ~ "Gene list",
      REASON == "FMT" ~ "Quality/Depth",
      REASON == "INHERITANCE" ~ "Inheritance/Frequency",
      REASON == "COMPOUND" ~ "Inheritance/Frequency",
      TRUE ~ str_to_sentence(REASON)
    )) %>%
    group_by(REASON) %>% 
    summarise(n = n(), STEP = min(STEP), .groups = 'drop') %>%
    arrange(STEP) %>%
    mutate(n = n_init - cumsum(n)) %>%
    add_row(REASON = "Initial", n = n_init, STEP = 0, .before = 1) %>%
    mutate(REASON = factor(REASON, levels = unique(rev(REASON))))  %>%
    ggplot(aes(REASON, n)) +
    geom_col(aes(fill = REASON), show.legend = FALSE) +
    geom_label(aes(y = pmax(n, 1), label = str_c('n=', map_chr(n, format, big.mark = ','))), hjust=1) +
    scale_y_continuous(
      trans = "log1p",
      breaks = c(0, 10**seq(1, max(2, ceiling(log10(n_init))))),
    ) +
    coord_flip() +
    labs(x = 'Filter', y = 'Remaining Gene-Variants') 

  saveRDS(plot, str_c(output, '.rds'))
  ggsave(str_c(output, '.png'), width = 7, height = 4)

}

PRINT_STR <- function(x) {
  capture.output(str(x)) %>% 
    str_c(collapse = '\n') %>% 
    message()
}

doc <- "
Usage:
  filter.R <ped> <gene_set> <options> ... [options]

Options:
  ped                         Pedigree file.
  gene_set                    File container ensembl gene ids of intererst.
  options                     Filter options Json file.
  --short-var=<TSV>           Short Variants TSV input.
  --struc-var=<TSV>           Structural Variants TSV input.
  --output=<prefix>           Output file prefix [default: output].
  --cav-opts=<json>           Json file with additional options for cavalier package.
"

# run main function
invisible(MAIN(docopt(doc)))