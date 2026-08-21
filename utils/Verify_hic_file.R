#!/usr/bin/Rscript
# Verify that a .hic file made by 6_make_hic_file.sh reproduces the rfy_hic2
# matrices. Uses "juicer_tools dump" (no extra R package needed).
#
# Example:
#   Rscript Verify_hic_file.R --hic NAME.hic --juicer juicer_tools.jar \
#       --rds data/NAME/20kb/Raw/ALL.rds --norm NONE --resolution 20000 --chr1 I --chr2 I
#   Rscript Verify_hic_file.R --hic NAME.hic --juicer juicer_tools.jar \
#       --rds data/NAME/20kb/ICE2/ALL.rds --norm ICE --resolution 20000 --chr1 I --chr2 II

suppressPackageStartupMessages(library("optparse"))
option_list <- list(
  make_option(c("--hic"), help=".hic file"),
  make_option(c("--juicer"), help="juicer_tools jar"),
  make_option(c("--rds"), help="rfy_hic2 matrix (ALL.rds or <chr>.rds)"),
  make_option(c("--norm"), default="NONE", help="normalization in .hic (NONE/ICE/KR)"),
  make_option(c("--resolution"), help="resolution in bp"),
  make_option(c("--chr1"), help="chromosome 1"),
  make_option(c("--chr2"), default="NA", help="chromosome 2 (default: same as chr1)"),
  make_option(c("--java_mem"), default="8g", help="java heap"),
  make_option(c("--tolerance"), default="1e-4", help="relative tolerance to report PASS")
)
opt <- parse_args(OptionParser(option_list=option_list))

FILE_hic <- as.character(opt["hic"])
JUICER <- as.character(opt["juicer"])
FILE_rds <- as.character(opt["rds"])
NORM <- as.character(opt["norm"])
RES <- as.numeric(as.character(opt["resolution"]))
CHR1 <- as.character(opt["chr1"])
CHR2 <- as.character(opt["chr2"]); if(CHR2 == "NA") CHR2 <- CHR1
TOL <- as.numeric(as.character(opt["tolerance"]))

FILE_dump <- tempfile(fileext=".txt")
cmd <- sprintf("java -Xmx%s -jar %s dump observed %s %s %s %s BP %d %s", as.character(opt["java_mem"]), JUICER, NORM, FILE_hic, CHR1, CHR2, RES, FILE_dump)
status <- system(cmd, ignore.stdout=TRUE, ignore.stderr=TRUE)
if(status != 0) stop("juicer dump failed: ", cmd)
D <- read.table(FILE_dump, header=FALSE, sep="\t", col.names=c("pos1", "pos2", "score"))
D <- D[!is.na(D$score), ]

map <- readRDS(FILE_rds)
rn <- rownames(map)
info <- do.call(rbind, strsplit(rn, ":"))
chr <- info[,1]; start <- as.numeric(info[,2])
i1 <- which(chr == CHR1); i2 <- which(chr == CHR2)
if(length(i1) == 0 || length(i2) == 0) stop("chromosome not found in rds")
sub <- map[i1, i2, drop=FALSE]
rownames(sub) <- start[i1]; colnames(sub) <- start[i2]

# rds -> long format (upper triangle for intra, all for inter)
df <- data.frame(pos1=rep(as.numeric(rownames(sub)), times=ncol(sub)),
                 pos2=rep(as.numeric(colnames(sub)), each=nrow(sub)),
                 rds=as.vector(sub))
if(CHR1 == CHR2) df <- df[df$pos1 <= df$pos2, ]
df <- df[!is.na(df$rds) & df$rds != 0, ]

# dump -> same key (dump gives bin start; orientation pos1<=pos2 for intra)
if(CHR1 == CHR2){
  sw <- D$pos1 > D$pos2
  tmp <- D$pos1[sw]; D$pos1[sw] <- D$pos2[sw]; D$pos2[sw] <- tmp
}
D <- D[D$score != 0, ]

M <- merge(df, D, by=c("pos1", "pos2"), all=TRUE)
only_rds <- sum(is.na(M$score))
only_hic <- sum(is.na(M$rds))
both <- M[!is.na(M$score) & !is.na(M$rds), ]
rel <- abs(both$score - both$rds) / pmax(abs(both$rds), 1e-12)

cat(sprintf("%s  %s  %s:%s  %dbp\n", basename(FILE_hic), NORM, CHR1, CHR2, RES))
cat(sprintf("  cells in both          : %d\n", nrow(both)))
cat(sprintf("  non-zero only in rds   : %d\n", only_rds))
cat(sprintf("  non-zero only in .hic  : %d\n", only_hic))
cat(sprintf("  max |relative diff|    : %.3e\n", if(nrow(both)) max(rel) else NA))
cat(sprintf("  sum rds / sum hic      : %.6f\n", sum(both$rds) / sum(both$score)))
cat(sprintf("  correlation            : %.8f\n", if(nrow(both) > 2) cor(both$rds, both$score) else NA))
ok <- only_rds == 0 && only_hic == 0 && nrow(both) > 0 && max(rel) < TOL
cat(if(ok) "  RESULT: PASS\n" else "  RESULT: CHECK\n")
