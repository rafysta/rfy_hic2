# Correct Hi-C bias by ICE2

suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="Distance normalized matrix file"),
  make_option(c("-o", "--out"),help="Normalized matrix file"),
  make_option(c("--log"), default="NA", help="log file"),
  make_option(c("--inter"), default="NA", help="read for inter-chromosome"),
  make_option(c("--times"), default="30", help="how many times apply normalization"),
  make_option(c("-t", "--threshold"), default=0.02, help="cut off threshold (default 0.02). Line with only less than this number of bin has score will remove
                Value with 10 or more than 10 will be used as cut off threshold value"),
  make_option(c("-q", "--quiet"), default="FALSE", help="don't output log")
)
opt <- parse_args(OptionParser(option_list=option_list))

FILE_matrix <- as.character(opt["in"])
FILE_out <- as.character(opt["out"])
FILE_inter <- as.character(opt["inter"])
Threshold <- as.numeric(as.character(opt["threshold"]))
FLAG_quiet <- as.character(opt["quiet"])

FILE_object <- sub(".matrix", ".rds", FILE_matrix)
if(as.character(opt["log"]) == "NA"){
  FILE_log <- sub(".matrix", ".log", FILE_out)
}else{
  FILE_log <- as.character(opt["log"])
}
if(!file.exists(FILE_object)){
  if(file.exists(FILE_matrix)){
    map <- as.matrix(read.table(FILE_matrix, header=TRUE, check.names = FALSE))
  }else{
    cat("There is not", FILE_matrix, "file\n")
    q()
  }
}else{
  map <- readRDS(FILE_object)
}
r <- rownames(map)

SUM_bin <- apply(map, 1, sum)

if(Threshold > 10){
  index_remove <- which(SUM_bin < Threshold)  # considered threshold as read number
}else{
  index_remove <- which(SUM_bin < quantile(SUM_bin[SUM_bin > 0],prob=Threshold))   # # considered threshold as %
  
  ### consider how much % of bins are zero (Gave up since variance may become strange)
  # index_remove <- which(sum(SUM_bin > 0) < (length(SUM_bin) * Threshold))
  
}
map[index_remove, ] <- NA
map[,index_remove] <- NA


#------------------------------------------------
# Read inter-chromosome information if present
#------------------------------------------------
if(FILE_inter != "NA"){
  D <- read.table(FILE_inter, sep="\t", header=F, row.names = 1)
  INTER <- D[,1]
  names(INTER) <- rownames(D)
}

Single <- function(m, b){
  Db <- apply(m, 2, sum, na.rm=TRUE)
  
  # Correct bias from inter-chromosome values if present
  if(FILE_inter != "NA"){
    Db <- Db + INTER / (b / mean(b[b!=0], na.rm=T))
  }
  
  Db <- Db / mean(Db[Db != 0])
  Db <- ifelse(Db == 0, 1, Db)
  
  d <- nrow(m)
  m <- m / matrix(rep(Db, times=d), nrow=d)
  m <- m / matrix(rep(Db, each=d), nrow=d)

  list(map=m, bias=Db)
}


multi <- function(m, times){
  B <- rep(1, length(r))
  
  # Get initial variance
  initial_var <- apply(m, 2, sum, na.rm=TRUE)
  if(FILE_inter != "NA"){
    initial_var <- initial_var + INTER
  }
  initial_var <- initial_var / mean(initial_var[initial_var != 0], na.rm=T)
  initial_var <- ifelse(initial_var == 0, 1, initial_var)
  initial_var <- var(initial_var)
  if(FLAG_quiet == "FALSE"){
    cat("Variance at 0 times:\t", initial_var, "\n", sep="", file = FILE_log, append = TRUE)
  }
  
  for(i in 1:times){
    S <- Single(m, B)
    m <- S$map
    B <- B * S$bias
    if(FLAG_quiet == "FALSE"){
      cat("Variance at ", i, " times:\t", var(S$bias), "\n", sep="", file = FILE_log, append = TRUE)
    }
  }
  m
}

options(warn=-1)
TIMES_apply <- as.numeric(as.character(opt["times"]))
map <- multi(map, TIMES_apply)


colnames(map) <- r
rownames(map) <- r
write.table(map, file=FILE_out, append=TRUE, quote=FALSE, sep="\t", eol="\n", row.names=TRUE, col.names=NA)



