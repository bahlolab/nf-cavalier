#!/usr/bin/env Rscript

stopifnot(
  require(tidyverse), 
  require(cavalier),
  require(docopt)
)

doc <- "
Usage:
  cavalier_init.R <options> <lists>

Options:
  options       Cavalier Options.
  lists         Comma separated list of gene lists or regions, e.g. 'G4E:ALL,PAA:202,custom_list.tsv,chr1:100000-200000'.
"

opts <- docopt(doc)
cav_opts <- jsonlite::fromJSON(opts$options)

do.call(set_cavalier_opt, cav_opts)

build_caches(PanelApp = FALSE, Genes4Epilepsy = FALSE)

# set options to latest if unset
cav_opts$hgnc_version    <- cavalier::get_cavalier_opt('hgnc_version'   , cavalier:::get_hgnc_version()   )
cav_opts$hpo_version     <- cavalier::get_cavalier_opt('hpo_version'    , cavalier:::get_hpo_version()    )
cav_opts$mi_omim_version <- cavalier::get_cavalier_opt('mi_omim_version', cavalier:::get_mi_omim_version())
cav_opts$gencode_version <- cavalier::get_cavalier_opt('gencode_version', cavalier:::get_gencode_version())

versions <- tribble(
  ~name, ~version,
  'HGNC', cav_opts$hgnc_version,
  'HPO', cav_opts$hpo_version,
  'Monarch Initiative: OMIM', cav_opts$mi_omim_version,
  'GENCODE', cav_opts$gencode_version,
)

hash <- digest::digest(cav_opts)
# write options
cat(
  jsonlite::toJSON(cav_opts),
  file = str_c('cavalier_options.', hash, '.json')
)

# gene_lists

MAP_IDS <- function(x) {
  
  req_cols <- c('symbol', 'gene', 'hgnc_id', 'ensembl_gene_id', 'entrez_id')
  stopifnot(
    length(intersect(colnames(x), req_cols)) > 0
  )
  
  x %>% 
    bind_rows(req_cols %>% setNames(.,.) %>% map_dfc(~ character())) %>% 
    mutate(
      entrez_id = as.integer(entrez_id),
      symbol = coalesce(symbol, gene),
      hgnc_id = coalesce(
        hgnc_id,
        hgnc_ensembl2id(ensembl_gene_id),
        hgnc_entrez2id(entrez_id),
        hgnc_sym2id(symbol),
      ),
      symbol = coalesce(symbol, hgnc_id2sym(hgnc_id)),
      ensembl_gene_id = coalesce(ensembl_gene_id, hgnc_id2ensembl(hgnc_id)),
      entrez_id = coalesce(entrez_id, hgnc_id2entrez(hgnc_id)),
    ) %>% 
    select(-gene)
}

gene_set <- character()
dir.create('output')

########## External gene lists ###############
ext_lists <- 
  c(str_split(opts$lists, pattern = ',', simplify = T)) %>% 
  keep(str_detect, '(G4E|PAA|PAE|HP|HGNC):')

for (id in ext_lists) {
  lst <- 
    cavalier::get_gene_list(id) %>% 
    arrange_all()
  
  hash <- digest::digest(lst)
  
  gene_set <- union(gene_set, na.omit(lst$ensembl_gene_id))

  write_tsv(
    lst,
    file = str_c("output/", str_replace_all(id, ":", "_"), ".", hash, ".tsv")
  )
  
  versions <-
    versions %>%
    add_row(
      name = str_c(first(lst$list_name), ' (', first(lst$list_id), ')'),
      version = first(lst$list_version)
    )
}

####### Region Gene List ###############
regions <-
  c(str_split(opts$lists, pattern = ',', simplify = T)) %>% 
  keep(str_detect, '^[^:]+:[0-9]+-[0-9]+$')

for (reg in regions) {
  reg_chrom <- str_extract(reg, '^[^:]+(?=:)')
  reg_start <- str_extract(reg, '(?<=:)[0-9]+(?=-)') %>% as.integer()
  reg_end   <- str_extract(reg, '(?<=-)[0-9]+$') %>% as.integer()
  
  lst <-
    get_gencode_coords() %>% 
    filter(chromosome == reg_chrom, start < reg_end, end > reg_start) %>% 
    select(ensembl_gene_id, hgnc_id) %>% 
    distinct() %>% 
    MAP_IDS() %>% 
    mutate(
      list_id = str_c('region:', reg_chrom, '_', reg_start, '_', reg_end),
      list_name = list_id,
      list_version = cav_opts$gencode_version) %>% 
    arrange_all()
  
  gene_set <- union(gene_set, na.omit(lst$ensembl_gene_id))
  
  hash <- digest::digest(lst)
  
  write_tsv(
    lst, 
    file = str_c('output/', 'region_', reg_chrom, '_', reg_start, '_', reg_end, '.', hash, '.tsv')
  )
}

############## Local gene lists ###############
loc_lists <- 
  c(str_split(opts$lists, pattern = ',', simplify = T)) %>% 
  discard(str_detect, '(G4E|PAA|PAE|HP|HGNC):') %>% 
  discard(str_detect, '^[^:]+:[0-9]+-[0-9]+$')

for (fn in loc_lists) {
  lst <-
    read_tsv(fn, col_types = cols(.default = "c")) %>% 
    MAP_IDS() %>% 
    arrange_all()
  
  hash <- digest::digest(lst)
  
  gene_set <- union(gene_set, na.omit(lst$ensembl_gene_id))
  
  write_tsv(
    lst, 
    file = str_c('output/', str_remove(basename(fn), '.tsv$'), '.', hash, '.tsv')
  )
}

gene_set <- sort(unique(gene_set))
hash <- digest::digest(gene_set)

write_lines(
  gene_set,
  file = str_c('output/gene_set.', hash, '.txt')
)

write_tsv(versions, 'versions.tsv')



