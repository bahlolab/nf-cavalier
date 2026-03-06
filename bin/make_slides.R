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
  slide_info <- jsonlite::fromJSON(opts$slide_info)
  message('Using slide info:')
  PRINT_STR(slide_info)
  
  if (!is.null(opts$cav_opts)) {
    cavalier::set_options_from_json(opts$cav_opts)
  }
  
  gene_lists <- c(str_split(opts$gene_lists, ',', simplify = T))
  igv_pngs <- c(str_split(opts$igv, ',', simplify = T))
  svpv_pngs <- c(str_split(opts$svpv, ',', simplify = T))
  samplots  <- c(str_split(opts$samplot, ',', simplify = T))
  output <- str_c(opts$output, ".pptx")
  max_short_per_deck <- as.integer(opts$max_short_per_deck)
  max_struc_per_deck <- as.integer(opts$max_struc_per_deck)
  
  ################# CHECK ARGS ######################
  exists_or_none <- function(x) { map_lgl(x, ~ . == 'NONE' | file.exists(.)) }
  stopifnot(
    exists_or_none(opts$short_var),
    exists_or_none(opts$struc_var),
    file.exists(opts$ped),
    all(file.exists(gene_lists)),
    exists_or_none(opts$short_flt_plot),
    exists_or_none(opts$struc_flt_plot),
    all(exists_or_none(igv_pngs)),
    all(exists_or_none(svpv_pngs)),
    all(exists_or_none(samplots)),
    all(c('SHORT', 'STRUC') %in% names(slide_info)),
    'DEFAULT' %in% names(slide_info$SHORT),
    'DEFAULT' %in% names(slide_info$STRUC)
  )
  
  ############## READ PEDIGREE   ################
  
  pedigree <- cavalier::read_ped(opts$ped)
  
  ############## CHECK GENE LIST ###############
  
  gene_list <- 
    c(str_split(opts$gene_lists, ',', simplify = T)) %>% 
    map_df(read_tsv, col_types = cols(.default = col_character()))
  
  stopifnot(
    'ensembl_gene_id' %in% colnames(gene_list),
    nrow(filter(gene_list, !is.na(ensembl_gene_id))) > 0
  )
  
  if (nrow(filter(gene_list, is.na(ensembl_gene_id)))) {
    warning('Excluded ', nrow(filter(gene_list, is.na(ensembl_gene_id))), ' entries from Gene list with missing ensembl_gene_id')
  }
  
  ########### LOAD VARIANTS ######################
  empty_cand <- tibble(SYMBOL = character(), Gene = character(), variant_id = character(), GT = tibble())
  
  short_cand <- empty_cand
  if (opts$short_var != 'NONE') {
    short_cand <- readRDS(opts$short_var) 
  }
  
  struc_cand <- empty_cand
  if (opts$struc_var != 'NONE') {
    struc_cand <- readRDS(opts$struc_var) 
  }
  
  ########### SHORT+STRUC SHARED FEATURES ###################
  ########### GTEX PLOTS ########################
  GTEX <- 
    bind_rows(
      short_cand %>% select(SYMBOL, Gene),
      struc_cand %>% select(SYMBOL, Gene),
    ) %>% 
    distinct() %>% 
    mutate(GTEX = map2(SYMBOL, Gene, cavalier::plot_gtex_expression)) %>% 
    select(Gene, GTEX) %>% 
    group_by(Gene) %>% 
    slice(1)
  
  ########### OMIM TABLE ########################
  OMIM <- 
    bind_rows(
      short_cand %>% select(Gene),
      struc_cand %>% select(Gene),
    ) %>% 
    distinct() %>%
    inner_join(
      get_omim_disease_map() %>% 
        select(Gene = ensembl_id, disease_id, inheritance, disease_name),
      by = 'Gene'
    ) %>% 
    distinct() %>% 
    transmute(
      Gene,
      OMIM = str_c(disease_name, ' [', replace_na(inheritance, '-'), ']'),
      OMIM_url = str_c('https://omim.org/entry/', str_extract(disease_id, '\\d+$'))
    ) %>% 
    nest(OMIM = -Gene)
  
  ########### GENE LIST TABLE ########################
  LISTS <-
    gene_list %>% 
    mutate(list_name_url = case_when(
      str_starts(list_id, 'PAA:') ~ str_c('https://panelapp-aus.org/panels/',
                                          str_extract(list_id, '(?<=PAA:)\\d+')),
      str_starts(list_id, 'PAE:') ~ str_c('https://panelapp.genomicsengland.co.uk/panels/',
                                          str_extract(list_id, '(?<=PAE:)\\d+')),
      str_starts(list_id, 'HP:') ~ str_c('https://hpo.jax.org/app/browse/term/',
                                         list_id),
      str_starts(list_id, 'G4E:') ~ 'https://bahlolab.github.io/Genes4Epilepsy/'
    )) %>%
    select(Gene = ensembl_gene_id, `Gene list` = list_name, `Gene list_url` = list_name_url, Version = list_version, any_of('inheritance')) %>% 
    semi_join( 
      bind_rows(
        short_cand %>% select(Gene),
        struc_cand %>% select(Gene),
      ),
      by = 'Gene'
    ) %>% 
    nest(LISTS = -Gene)
  
  ########### PEDIGREE PLOTS ########################
  if (nrow(pedigree) > 2) {
    PEDIGREE <-
      bind_rows(
        struc_cand %>% select(variant_id, GT),
        short_cand %>% select(variant_id, GT)
      ) %>% 
      distinct() %>% 
      unnest(GT) %>%
      pivot_longer(-variant_id, names_to = 'id', values_to = 'gt') %>% 
      right_join(.,
                 expand_grid(pedigree, variant_id = unique(.$variant_id),
                             by = 'id')
      ) %>% 
      mutate(gt = replace_na(gt, '???'),
             label = str_c(id, gt, sep = '\n')) %>% 
      nest(PEDIGREE = -variant_id) %>% 
      mutate(PEDIGREE = map(PEDIGREE, distinct)) %>%
      mutate(PEDIGREE = map(PEDIGREE, plot_ped))
  } else {
    PEDIGREE <-
      bind_rows(
        struc_cand %>% select(variant_id, GT),
        short_cand %>% select(variant_id, GT)
      ) %>% 
      distinct() %>% 
      mutate(PEDIGREE = map(variant_id, ~ NULL))
  }
  
  file.copy(cavalier:::get_slide_template(), output, TRUE)

  if (opts$short_flt_plot != "NONE") {
    ##### ADD TITLE SLIDE #####
    officer::read_pptx(output) %>%
      officer::add_slide(layout = "Title and Content") %>%
      officer::ph_with(str_c(opts$output, ': SNVs and Indels (n=', nrow(short_cand), ')'), location = officer::ph_location_type("title")) %>%
      officer::ph_with(readRDS(opts$short_flt_plot) + theme_gray(base_size = 16), location =  officer::ph_location_type(type = "body"))  %>% 
      print(target = output)
  }
  
  ########### CREATE SHORT SLIDES ##############
  if (opts$short_var != "NONE") {
    ########### IGV Plots ########################
    IGV <-
      tibble(
        png = igv_pngs,
        id = str_extract(png, "(?<=SID_).+(?=\\.VID_)"),
        variant_id = str_extract(png, "(?<=VID_).+(?=\\.png$)"),
      ) %>%
      inner_join(
        short_cand %>%
          select(variant_id, GT) %>%
          unnest(GT) %>%
          pivot_longer(-variant_id, names_to = "id", values_to = "GT"),
        by = c("variant_id", "id")
      ) %>%
      transmute(
        id = str_c(id, ": ", GT),
        png,
        variant_id
      ) %>%
      nest(IGV = -variant_id) %>%
      mutate(IGV = map(IGV, cavalier::plot_png_facets, crop_left = 70, crop_right = 120))

    ########### SHORT VAR INFO TABLE ########################
    SHORT_FIELDS_ALL <-
      reduce(slide_info$SHORT, c) %>%
      (function(x) x[unique(names(x))]) %>%
      unlist()

    SHORT_FIELDS <-
      short_cand %>%
      select(TYPE) %>%
      distinct() %>%
      mutate(FIELDS = map(TYPE, function(x) {
        fields <- names(slide_info$SHORT$DEFAULT)
        custom <- names(slide_info$SHORT[[x]])
        union(fields, custom)
      })) %>%
      with(setNames(FIELDS, TYPE))

    SHORT_VAR_INFO <-
      short_cand %>%
      # add/modify columns
      mutate(
        # need to maintain Gene
        Gene2 = Gene,
        # reporting summary columns
        broad_id = str_c(CHROM, POS, REF, ALT, sep = "-"),
        gnomAD = str_c("AF=", signif(replace_na(gnomad_AF, 0), 2), "; AC=", replace_na(gnomad_AC, 0), "; Hom=", replace_na(gnomad_nhomalt, 0)),
        Cohort = str_c("AF=", signif(replace_na(AF, 0), 2), "; AC=", replace_na(AC, 0)),
        SpliceAI = str_c("AG=", SpliceAI_pred_DS_AG, "; DG=", SpliceAI_pred_DS_DG, "; AL=", SpliceAI_pred_DS_AL, "; DL=", SpliceAI_pred_DS_DL),
        AlphaMissense = str_c(am_class, "(", am_pathogenicity, ")"),
        dbSNP = str_extract(Existing_variation, "rs[0-9]+"),
        # add GRCh38 for mutatylzer compatibility
        HGVSg = str_replace(HGVSg, "^([^:]+):(.*)$", "GRCh38(\\1):\\2"),
        # prefer coding & protein, or coding, or genomic. Drop IDs to better fit
        HGVS = coalesce(
          str_c(str_remove(HGVSc, "^.+:(?=[cp])"), "; ", str_remove(HGVSp, "^.+:(?=[cp])")),
          str_remove(HGVSc, "^.+:(?=[cp])"),
          HGVSg
        ),
        # # add URLS to slides
        gnomAD_url = str_c(
          "https://gnomad.broadinstitute.org/variant/",
          URLencode(broad_id),
          "?dataset=gnomad_r4"
        ),
        HGVS_url = str_c(
          "https://mutalyzer.nl/normalizer/",
          URLencode(HGVSg)
        ),
        SpliceAI_url = str_c(
          "https://spliceailookup.broadinstitute.org/#hg=38&variant=",
          URLencode(broad_id)
        ),
        promoterAI_url = str_c(
          "https://promoterailookup.broadinstitute.org/#hg=38&variant=",
          URLencode(broad_id)
        ),
        Gene_url = str_c(
          "https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=",
          URLencode(Gene)
        ),
        CLNSIG_url = str_c(
          "https://www.ncbi.nlm.nih.gov/clinvar/variation/",
          CLNVID
        ),
      ) %>%
      select(
        variant_id,
        Gene2,
        TYPE,
        all_of(SHORT_FIELDS_ALL),
        any_of(
          setNames(
            str_c(SHORT_FIELDS_ALL, "_url"),
            str_c(names(SHORT_FIELDS_ALL), "_url")
          )
        )
      ) %>%
      nest(VAR_INFO = -c(variant_id, Gene2, TYPE)) %>%
      rename(Gene = Gene2) %>%
      mutate(VAR_INFO = map2(VAR_INFO, TYPE, function(VI, TYPE_) {
        select(VI, all_of(SHORT_FIELDS[[TYPE_]]), any_of(str_c(SHORT_FIELDS[[TYPE_]], "_url")))
      }))


    ########### SHORT SLIDE DATA ########################
    SHORT_SLIDE_DATA <-
      short_cand %>%
      select(Gene, SYMBOL, variant_id) %>%
      distinct() %>%
      mutate(TITLE = str_c(opts$output, ": ", SYMBOL, " - ", variant_id)) %>%
      select(TITLE, Gene, SYMBOL, variant_id) %>%
      left_join(SHORT_VAR_INFO, by = c("Gene", "variant_id")) %>%
      left_join(IGV, by = "variant_id") %>%
      left_join(PEDIGREE, by = "variant_id") %>%
      left_join(OMIM, by = "Gene") %>%
      left_join(LISTS, by = "Gene") %>%
      left_join(GTEX, by = "Gene") %>%
      arrange(TITLE)

    ############# SHORT SLIDE LAYOUT #####################
    if (ncol(short_cand$GT) == 1) {
      short_layout <-
        cavalier::slide_layout(
          c("VAR_INFO", "IGV", "GTEX"),
          c("OMIM", "LISTS"),
          heights = c(23, 8),
          title_height = 0.09,
          pad = 0.015,
          transpose = "VAR_INFO"
        )
    } else {
      short_layout <-
        bind_rows(
          cavalier::slide_layout(
            c("VAR_INFO", "PEDIGREE", "GTEX"),
            c("OMIM", "LISTS"),
            heights = c(23, 8),
            title_height = 0.09,
            pad = 0.015,
            transpose = "VAR_INFO"
          ),
          cavalier::slide_layout(
            c("IGV"),
            slide_num = 2L,
            title_height = 0.09,
            pad = 0.015
          )
        )
    }

    message("----- Creating Short Variant Slides ------")

    if (nrow(SHORT_SLIDE_DATA) > max_short_per_deck) {
      ##### TRUNCATE #####
      officer::read_pptx(output) %>%
        officer::add_slide(layout = "Title and Content") %>%
        officer::ph_with(
          str_c("Limited to ", max_short_per_deck, " of ", nrow(SHORT_SLIDE_DATA), " short variants"),
          location = officer::ph_location_type("title")
        ) %>%
        print(target = output)

      SHORT_SLIDE_DATA <- slice(SHORT_SLIDE_DATA, seq_len(max_short_per_deck))
    }

    cavalier::create_slides(
      slide_template = output,
      slide_layout = short_layout,
      slide_data = SHORT_SLIDE_DATA,
      output = output
    )
  }

  if (opts$struc_flt_plot != "NONE") {
     ##### ADD TITLE SLIDE #####
    officer::read_pptx(output) %>%
      officer::add_slide(layout = "Title and Content") %>%
      officer::ph_with(str_c(opts$output, ': SVs (n=', nrow(struc_cand), ')'), location = officer::ph_location_type("title")) %>%
      officer::ph_with(readRDS(opts$struc_flt_plot) + theme_gray(base_size = 16), location =  officer::ph_location_type(type = "body"))  %>% 
      print(target = output)
  }
  
  if (opts$struc_var != 'NONE') { 
    ########### SVPV Plots ########################
    SVPV <-
      tibble( png = svpv_pngs) %>% 
      tidyr::extract(
        png,
        into = c("CHROM", "POS", "SVTYPE"),
        regex = "^SVPV_[^\\.]+\\.([^\\.]+)\\.([0-9]+)\\.([^\\.]+)",
        remove = FALSE
      ) %>% 
      mutate(POS = as.numeric(POS)) %>% 
      inner_join(
        struc_cand %>% 
          select(CHROM, POS, SVTYPE, variant_id) %>% 
          distinct(),
        by = join_by(CHROM, POS, SVTYPE)
      ) %>% 
      transmute(
        id = 'x',
        png,
        variant_id
      ) %>% 
      nest(SVPV = -variant_id) %>% 
      mutate(SVPV = 
               SVPV %>% 
               map(cavalier::plot_png_facets, crop_left = 0, crop_right = 0) %>% 
               map(~ . + ggplot2::theme(strip.text = element_blank())) # kludge
      )

    ########### SAMPLOTS ########################
    SAMPLOT <-
      tibble(png = samplots) %>% 
      tidyr::extract(
        png,
        into = c("CHROM", "POS", "SVTYPE", "SVLEN"),
        regex = "_([^\\._]+)-([0-9]+)-([^\\.]+)-([_0-9]+)\\.png",
        remove = FALSE
      ) %>% 
      mutate(POS = as.numeric(POS), SVLEN = as.numeric(SVLEN)) %>% 
      inner_join(
        struc_cand %>% 
          select(CHROM, POS, SVTYPE, SVLEN, variant_id) %>% 
          mutate(SVLEN = abs(SVLEN)) %>% 
          distinct(),
        by = join_by(CHROM, POS, SVTYPE, SVLEN)
      ) %>% 
      transmute(
        id = 'x',
        png,
        variant_id
      ) %>% 
      nest(SAMPLOT = -variant_id) %>% 
      mutate(SAMPLOT = 
               SAMPLOT %>% 
               map(cavalier::plot_png_facets, crop_left = 0, crop_right = 0) %>% 
               map(~ . + ggplot2::theme(strip.text = element_blank())) # kludge
      )
    
    ########### STRUC VAR INFO TABLE ########################
    
    STRUC_FIELDS_ALL <- 
      reduce(slide_info$STRUC, c) %>% 
      (function(x) x[unique(names(x))]) %>% 
      unlist()
    
    
    STRUC_VAR_INFO <-
      struc_cand %>% 
      # add/modify columns
      mutate(
        # need to maintain Gene
        Gene2 = Gene,
        # reporting summary columns
        gnomAD = str_c("AF=", signif(replace_na(pop_AF, 0), 2), "; Hom=",  replace_na(pop_hom, 0)),
        Cohort = str_c("AF=", signif(replace_na(AF, 0), 2), "; AC=", replace_na(AC, 0)),
        # add GRCh38 for mutatylzer compatibility
        HGVS = case_when(
          SVTYPE %in% c("DEL", "DUP", "INV", "CNV") ~ str_c(CHROM, ':g.', POS, "_", END, str_to_lower(SVTYPE)),
          SVTYPE == "INS" ~ str_c(CHROM, ':g.', POS, "_", POS + 1L, "ins"),
          TRUE ~ NA_character_
        ),
        Region = if_else(
          END > POS,
          str_c(CHROM, ':', POS, '-', END),
          str_c(CHROM, ':', POS)
        ),
        Region_url = {
          colour <- case_when(
            SVTYPE == "DEL" ~ "255,0,0",
            SVTYPE == "DUP" ~ "0,255,0",
            TRUE            ~ "0,0,255"
          )
          width <- pmax(250, END - POS)
          track <- str_c(
            'track name="', SVTYPE, '" visibility=2 color=', colour, '\n',
            CHROM, ' ', POS, ' ', coalesce(END, POS+1)
          )
          str_c(
            "https://genome.ucsc.edu/cgi-bin/hgTracks?db=hg38&",
            "position=", CHROM, ":", POS-width, "-", END+width, "&",
            "hgt.customText=", URLencode(track)
          )
        },
        # # add URLS to slides
        gnomAD_url = if_else(
          Gene == 'LARGE_SV',
          str_c(
            'https://gnomad.broadinstitute.org/region/',
            str_remove(CHROM, 'chr'), '-', POS, '-', END,
            '?dataset=gnomad_sv_r4'
          ),
          str_c(
            'https://gnomad.broadinstitute.org/gene/',
            Gene,
            '?dataset=gnomad_sv_r4'
          ),
        ),
        Gene_url = str_c(
          'https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=',
          if_else(Gene == 'LARGE_SV', NA_character_,  URLencode(Gene))
        )
      ) %>% 
      select(
        variant_id,
        Gene2,
        TYPE,
        all_of(STRUC_FIELDS_ALL),
        any_of(
          setNames(
            str_c(STRUC_FIELDS_ALL, '_url'),
            str_c(names(STRUC_FIELDS_ALL), '_url')
          )
        )
      ) %>% 
      nest(VAR_INFO = -c(variant_id, Gene2, TYPE)) %>% 
      mutate(VAR_INFO = map(VAR_INFO, head, 1)) %>% # remove dups
      rename(Gene = Gene2)
    
    ########### STRUC SLIDE DATA ########################
    STRUC_SLIDE_DATA <-
      struc_cand %>% 
      select(Gene, SYMBOL, variant_id) %>% 
      distinct() %>% 
      mutate(TITLE = str_c(opts$output, ': ', SYMBOL, ' - ', variant_id)) %>% 
      select(TITLE, Gene, SYMBOL, variant_id) %>% 
      left_join(STRUC_VAR_INFO, by = c('Gene', 'variant_id')) %>% 
      left_join(SVPV, by = 'variant_id') %>% 
      left_join(SAMPLOT, by = 'variant_id') %>% 
      left_join(PEDIGREE, by = 'variant_id') %>% 
      left_join(OMIM, by = 'Gene') %>% 
      left_join(LISTS, by = 'Gene') %>% 
      left_join(GTEX, by = 'Gene') %>% 
      arrange(TITLE)
    
    ############# STRUC SLIDE LAYOUT #####################  
    if (nrow(pedigree) > 1) {
      struc_layout <-
        cavalier::slide_layout(
          c('VAR_INFO', 'PEDIGREE', 'GTEX'),
          c('OMIM', 'LISTS'),
          heights = c(23, 8),
          title_height = 0.09,
          pad = 0.015,
          transpose = 'VAR_INFO'
        )
    } else {
      struc_layout <-
        cavalier::slide_layout(
          c('VAR_INFO', 'GTEX'),
          c('OMIM', 'LISTS'),
          heights = c(23, 8),
          title_height = 0.09,
          pad = 0.015,
          transpose = 'VAR_INFO'
        )
    }
    struc_layout <-
      bind_rows(
        struc_layout,
        cavalier::slide_layout(
          c('SVPV'),
          slide_num = 2L,
          title_height = 0.09,
          pad = 0.015
        ),
        cavalier::slide_layout(
          c('SAMPLOT'),
          slide_num = 3L,
          title_height = 0.09,
          pad = 0.015
        )
      )
    
    message("----- Creating Structural Variant Slides -----")

    if (nrow(STRUC_SLIDE_DATA) > max_struc_per_deck) {
      ##### TRUNCATE #####
      officer::read_pptx(output) %>%
        officer::add_slide(layout = "Title and Content") %>%
        officer::ph_with(
          str_c("Limited to ", max_struc_per_deck, ' of ', nrow(STRUC_SLIDE_DATA), ' structural variants'),
          location = officer::ph_location_type("title")
        ) %>%
        print(target = output)

      STRUC_SLIDE_DATA <- slice(STRUC_SLIDE_DATA, seq_len(max_struc_per_deck))
    }

    cavalier::create_slides(
      slide_template = output,
      slide_layout = struc_layout,
      slide_data = STRUC_SLIDE_DATA,
      output = output
    )
  }
}


PRINT_STR <- function(x) {
  capture.output(str(x)) %>% 
    str_c(collapse = '\n') %>% 
    message()
}

doc <- "
Usage:
  make_slides.R <ped> <gene_lists> <options> ... [options]

Options:
  ped                         Pedigree file.
  gene_lists                  Comma serparated list of gene list filenames.
  options                     Slide options Json file.
  --short-var=<RDS>           Short Variants RDS input.
  --short-flt-plot=<RDS>      Short Variants filtering plot.
  --struc-var=<RDS>           Structural Variants RDS input.
  --struc-flt-plot=<RDS>      Short Variants filtering plot.
  --igv=<PNG>                 IGV screenshot PNGs, comma separated.
  --svpv=<PNG>                SVPV PNGs, comma separated.
  --samplot=<PNG>             samplot PNGs, comma separated.
  --output=<prefix>           Output file prefix [default: output].
  --slide-info=<json>         Json file specifying fields to include in VAR_INFO.
  --cav-opts=<json>           Json file with additional options for cavalier package.
  --max-short-per-deck=<n>    Maximum short variant slides to create [default: 500].
  --max-struc-per-deck=<n>    Maximum stuctural variant slides to create [default: 500].
"

# run main function
invisible(MAIN(docopt(doc)))
