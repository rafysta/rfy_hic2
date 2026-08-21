#!/usr/bin/Rscript
# Convert rfy_hic2 bias vector(s) to the Juicer "addNorm" input format.
#
# Input bias file(s) are written by Bias_normalization_ICE2.R --bias_out:
#     bin            bias
#     I:0:19999      1.0213
#     I:20000:39999  NA          <- removed bin
#
# Output (appended to --out so that several resolutions can share one file):
#     vector<TAB>ICE<TAB>I<TAB>20000<TAB>BP
#     1.0213
#     NaN
#     ...
# For each chromosome floor(length / resolution) + 1 values are written
# (Juicer convention); bins missing from the bias file are written as NaN.
#
# In a .hic file the normalized value is raw_ij / (v_i * v_j), which is the
# same definition as the ICE2 bias, so the ICE matrix shown by Juicebox /
# HiCarta / straw is identical to ICE2/ALL.rds.

suppressPackageStartupMessages(library("optparse"))
option_list <- list(
  make_option(c("-i", "--in"), help="comma separated list of bias files (ALL_bias.txt, or I_bias.txt,II_bias.txt,...)"),
  make_option(c("-o", "--out"), help="output vector file (appended if exists)"),
  make_option(c("-l", "--length"), help="chromosome length file (fai or chr<TAB>length)"),
  make_option(c("-r", "--resolution"), help="resolution in bp (e.g. 20000)"),
  make_option(c("-n", "--name"), default="ICE", help="normalization name written into the .hic file [default ICE]"),
  make_option(c("-c", "--chr"), default="NA", help="comma separated chromosome list to output (default: all in length file)")
)
opt <- parse_args(OptionParser(option_list=option_list))

FILES_bias <- unlist(strsplit(as.character(opt["in"]), ","))
FILE_out <- as.character(opt["out"])
FILE_length <- as.character(opt["length"])
RESOLUTION <- as.numeric(as.character(opt["resolution"]))
NORM_NAME <- as.character(opt["name"])

D_len <- read.table(FILE_length, header=FALSE, sep="\t", stringsAsFactors=FALSE, quote="")[,1:2]
colnames(D_len) <- c("chr", "length")
if(as.character(opt["chr"]) != "NA"){
  CHRs <- unlist(strsplit(as.character(opt["chr"]), ","))
}else{
  CHRs <- D_len$chr
}

# read bias
D_bias <- do.call(rbind, lapply(FILES_bias, function(f){
  read.table(f, header=TRUE, sep="\t", stringsAsFactors=FALSE, colClasses=c("character", "numeric"))
}))
tmp <- do.call(rbind, strsplit(D_bias$bin, ":"))
D_bias$chr <- tmp[,1]
D_bias$start <- as.numeric(tmp[,2])
D_bias$index <- D_bias$start %/% RESOLUTION

fh <- file(FILE_out, open="a")
for(chr in CHRs){
  len <- D_len$length[D_len$chr == chr]
  if(length(len) == 0){
    cat("Warning:", chr, "is not in the chromosome length file. skipped\n", file=stderr())
    next
  }
  n_bin <- len %/% RESOLUTION + 1
  v <- rep(NA_real_, n_bin)
  d <- D_bias[D_bias$chr == chr, ]
  d <- d[d$index < n_bin, ]
  v[d$index + 1] <- d$bias
  v_str <- ifelse(is.na(v), "NaN", format(v, digits=10, trim=TRUE, scientific=FALSE))
  writeLines(paste("vector", NORM_NAME, chr, format(RESOLUTION, scientific=FALSE), "BP", sep="\t"), fh)
  writeLines(v_str, fh)
}
close(fh)
