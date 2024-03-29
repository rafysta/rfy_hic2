#!/usr/bin/Rscript
# Load length of chromosome

suppressWarnings(suppressMessages(library(data.table)))

suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"), default="NA", help="length file"),
  make_option(c("--include"), default="NA", help="list of including chromosomes. separated by ,"),
  make_option(c("--exclude"), default="NA", help="list of excluding chromosomes. separated by ,")
)
opt <- parse_args(OptionParser(option_list=option_list))

FILE_in <- as.character(opt["in"])
D_table <- as.data.frame(fread(FILE_in, select = c(1,2), header = FALSE, col.names = c("chr", "length")))
rownames(D_table) <- D_table$chr

TARGET_CHRs <- D_table$chr
CHR_in <- unlist(strsplit(as.character(opt["include"]), ","))
if(CHR_in[1] != "NA"){
  TARGET_CHRs <- CHR_in
}
CHR_ex <- unlist(strsplit(as.character(opt["exclude"]), ","))
if(CHR_ex[1] != "NA"){
  TARGET_CHRs <- setdiff(TARGET_CHRs, CHR_ex)
}

cat(TARGET_CHRs, sep=",")
cat("\n")
cat(D_table[TARGET_CHRs, "length"], sep=",")
