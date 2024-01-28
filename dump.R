#!/usr/bin/Rscript
# dump command similar to JUICER

suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(data.table)))

suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="matrix file"),
  make_option(c("-c", "--chr"), default="NA", help="chromosome"),
  make_option(c("-s", "--start"), default="NA", help="start region"),
  make_option(c("-e", "--end"), default="NA", help="end region"),
  make_option(c("-o", "--out"),help="output file")
)
opt <- parse_args(OptionParser(option_list=option_list))

options(scipen=10)
FILE_in <- as.character(opt["in"])
FILE_out <- as.character(opt["out"])
pchr <- as.character(opt["chr"])
pstart <- as.numeric(as.character(opt["start"]))
pend <- as.numeric(as.character(opt["end"]))

D_map <- fread(FILE_in)
D_map <- D_map %>% tidyr::separate(loc1, c("chr1", "start1", "end1"), ":", convert=TRUE, extra="merge") %>% tidyr::separate(loc2, c("chr2", "start2", "end2"), ":", convert=TRUE, extra="merge")
D_map <- D_map %>% filter(chr1==pchr, chr2==pchr, end1 >= pstart, end2 >= pstart, start1 <= pend, start2 <= pend)
write.table(D_map, FILE_out, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
