#!/usr/bin/Rscript
# output bad fragments


suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="fragment.txt"),
  make_option(c("-o", "--out"),help="bad fragment list"),
  make_option(c("-n", "--name"),help="sample name"),
  make_option(c("-g", "--png"),help="graph of read distribution")
)
opt <- parse_args(OptionParser(option_list=option_list))

lseq <- function(from=1, to=100000, length.out=6) {
  exp(seq(log(from), log(to), length.out = length.out))
}


D <- read.table(as.character(opt["in"]), sep="\t", header=T)
COUNT <- D[,"count"]
LEN <- D[,"length"]
NUM <- round(length(COUNT) * 0.0001)

x <- c(1:50, round(lseq(51, length(COUNT), length.out=80)))
y <- COUNT[x]
index_fit <- which(x > NUM & x < 1e5)
data_for_fit <- data.frame(x=log(x[index_fit]), y=y[index_fit])
fit <- lm(y ~ x, data=data_for_fit)

png(as.character(opt["png"]), width=20, height=20,  units="cm", res = 72, bg="white")
par(oma=c(0,0,0,0), mar=c(4,5,3,2))
plot(x, y, pch=20, cex=1, xlab="Ranking", ylab="Total read count", log='x', 
     cex.axis=1.8, cex.lab=2, main=as.character(opt["name"]), cex.main=1.8, xaxt="n")
y2 <- predict(fit, newdata = data.frame(x=log(x)))
lines(x,y2, col='red', lwd=2, lty=2)
NUM_cut <- min(which(y - y2 < 0))
abline(v=NUM_cut, col='blue', untf = T, lty=2)
axis(side=1, at = c(1, NUM_cut, 1e3,  length(COUNT)), labels = c(1, NUM_cut, 1e3, length(COUNT)), cex.axis=1.8)
dummy <- dev.off()

index_output <- 1:NUM_cut
OUT <- data.frame(chr=D[index_output,"chr"], fragNum=D[index_output,"fragNum"])
write.table(OUT, file = as.character(opt["out"]), sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE, eol = "\n")




