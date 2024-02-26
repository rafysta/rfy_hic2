# Draw contact map

suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="matrix file"),
  make_option(c("-o", "--out"),help="output png file"),
  make_option(c("--format"), default="rds", help="input file format. use matrix for tab deliminated text file (default: rds)"),
  make_option(c("--chr"),help="chromosome name all for all chromosome"),
  make_option(c("--distance"), default="FALSE", help="normalized by distance curve"),
  make_option(c("--distance2"), default="FALSE", help="normalized by distance curve (log2 score)"),
  make_option(c("--blank"), default="20", help="blank bin number between chromosomes"),
  make_option(c("--normalize"), default="NA", help="NA, average: average will be 1, probability: score were divided by total read"),
  make_option(c("--moving_average"), default=0, help="number of merging bin for moving average calculation"),
  make_option(c("--na"), default="min", help="how to treat na value. min, na, ave, zero. min replace with minimum value. ave take average of same distance, zero replace to zero"),
  make_option(c("--zero"), default="NA", help="how to treat 0 value. min, na, ave. min replace with minimum value. ave take average of same distance"),
  make_option(c("--matrix"), default="NULL", help="output matrix"),
  make_option(c("--start"), default="1", help="start position"),
  make_option(c("--end"), default="all", help="end position. all for end of the chromosome"),
  make_option(c("--chr2"), default="NULL", help="chromosome2 name. defula is same to chr"),
  make_option(c("--start2"), default="NULL", help="start2 position. default is same to start"),
  make_option(c("--end2"), default="NULL", help="end2 position. default is same to end"),
  make_option(c("--color"), default="matlab", help="color matlab or gentle, blue or red"),
  make_option(c("--unit"), default="p", help="unit to define score threshold p:percent or v:value"),
  make_option(c("--blur"), default=FALSE, help="if TRUE, make blur image"),
  make_option(c("--gaus_smooth"), default=FALSE, help="apply gaussian smoothing"),
  make_option(c("--corScore"), default=FALSE, help="if TRUE, calculate correlation score"),
  make_option(c("--linerColor"), default=FALSE, help="use linear color scale"),
  make_option(c("--min"), default="NULL", help="minimum score for drawing"),
  make_option(c("--max"), default="0.95", help="maximu score for drawing"),
  make_option(c("--width"), default="1000", help="width of output figure"),
  make_option(c("--height"), default="NULL", help="height of output figure"),
  make_option(c("--linev_chr"), default="NULL", help="location of vertical line"),
  make_option(c("--linev_pos"), default="NULL", help="location of vertical line , separated"),
  make_option(c("--lineh_chr"), default="NULL", help="location of horizontal line"),
  make_option(c("--lineh_pos"), default="NULL", help="location of horizontal line , separated"),
  make_option(c("--circle"), default="NULL", help="location pairs to draw circles on output"),
  make_option(c("--triangle"), default="FALSE", help="plot only half of triangle")
)
opt <- parse_args(OptionParser(option_list=option_list))

pallete <- c("#00007F", "blue", "#007FFF", 
                        "cyan","#7FFF7F", "yellow", "#FF7F00", "red", "#7F0000")
if(as.character(opt["color"]) == "gentle"){
  suppressWarnings(suppressMessages(library("RColorBrewer")))
  pallete <- rev(brewer.pal(10, "RdBu"))  # gentle color
}
if(as.character(opt["color"]) == "red"){
  suppressWarnings(library("RColorBrewer"))
  pallete <- brewer.pal(9, "Reds")
}
if(as.character(opt["color"]) == "blue"){
  suppressWarnings(library("RColorBrewer"))
  pallete <- brewer.pal(9, "Blues")
}
if(as.character(opt["color"]) == "yellow"){
  pallete <- rev(c(rgb(0,0,0), rgb(0.13604190193,0.06025908266,0.0358534453625), rgb(0.236596675144,0.0854393225134,0.0663292063043), 
  rgb(0.345308379611,0.104251700818,0.0859523214123), rgb(0.459650765971,0.118262288197,0.10370568771), 
  rgb(0.57886917165,0.12712196061,0.121683026697), rgb(0.694333453232,0.147366583596,0.135554156099), 
  rgb(0.757966046005,0.254807778863,0.115414575242), rgb(0.821231461948,0.346641504267,0.0789177160322), 
  rgb(0.87357362974,0.441355114094,0.0184645577569), rgb(0.887325704879,0.554597071914,0.013882477102), 
  rgb(0.895705175617,0.661630633721,0.0133922831093), rgb(0.898208608643,0.76566848057,0.0180193216995), 
  rgb(0.923430940957,0.85551584532,0.291204862021), rgb(0.977010668325,0.92623393319,0.660287806118), rgb(1,1,1)),space="Lab")
}

TakeMiddleV <- function(mat, minVal, maxVal){
  mat.new <- ifelse(mat < minVal, minVal, mat)
  ifelse(mat.new > maxVal, maxVal, mat.new)
}


Transform <- function(mat){
  d = dim(mat)[1]
  n = dim(mat)[2]
  mat.rev = t(mat[d+1-c(1:d), ])
  mat.rev
}


FILE_format <- as.character(opt["format"])
FILE_matrix <- as.character(opt["in"])
if(FILE_format == "rds"){
  FILE_object <- sub(".matrix", ".rds", FILE_matrix)
  if(!file.exists(FILE_object)){
    map <- as.matrix(read.table(FILE_matrix, header=TRUE, check.names = FALSE))
  }else{
    map <- readRDS(FILE_object)
  }
}else if(FILE_format == "matrix"){
  map <- as.matrix(read.table(FILE_matrix, header=TRUE, check.names = FALSE))
}else{
  cat("Unknown input file format")
  q()
}
map <- ifelse(is.infinite(map), NA, map)

r <- rownames(map)
LocList <- strsplit(r, ":")
LocMatrix <- matrix(unlist(LocList), ncol=3, byrow=TRUE)


# Normalization
Normalization = as.character(opt["normalize"])
if(Normalization == "average"){
  d <- nrow(map)
  map <- map / sum(map, na.rm=TRUE) * d * d
}else if(Normalization == "probability"){
  map <- map / sum(map, na.rm=TRUE)
}

if(eval(parse(text=as.character(opt["corScore"])))){
  # Convert to observed / expected matrix
  map_expect <- map
  NUM_LINE <- nrow(map)
  for(d in 0:(NUM_LINE-1)){
    index1 <- 1:(NUM_LINE - d)
    index2 <- index1 + d
    index3 <- cbind(index1, index2)
    index4 <- cbind(index2, index1)
    Average <- mean(as.numeric(map[index3]), na.rm=TRUE)
    map_expect[index3] <- Average
    map_expect[index4] <- Average
  }
  
  map <- ifelse(map_expect == 0, NA, map / map_expect)
  rm(map_expect)
  
  # If SD = 0, fill in 0
  sdlist <- apply(map,1,sd, na.rm=TRUE)
  index <- which(sdlist == 0)
  map[index, ] <- NA
  map[, index] <- NA
  
  getCor <- function(i){
    apply(map, 2, function(x) { cor(x, map[,i], use="pairwise.complete.obs", method="pearson")})
  }
  map <- rbind(sapply(1:ncol(map), getCor))
}

if(eval(parse(text=as.character(opt["distance"])))){
  # Convert to observed / expected matrix
  map_expect <- map
  NUM_LINE <- nrow(map)
  for(d in 0:(NUM_LINE-1)){
    index1 <- 1:(NUM_LINE - d)
    index2 <- index1 + d
    index3 <- cbind(index1, index2)
    index4 <- cbind(index2, index1)
    Average <- mean(as.numeric(map[index3]), na.rm=TRUE)
    map_expect[index3] <- Average
    map_expect[index4] <- Average
  }
  
  map <- ifelse(map_expect == 0, NA, map / map_expect)
  rm(map_expect)
}

if(eval(parse(text=as.character(opt["distance2"])))){
  # log2(Observed / Expect)のmatrixに変換する
  map_expect <- map
  NUM_LINE <- nrow(map)
  for(d in 0:(NUM_LINE-1)){
    index1 <- 1:(NUM_LINE - d)
    index2 <- index1 + d
    index3 <- cbind(index1, index2)
    index4 <- cbind(index2, index1)
    Average <- mean(as.numeric(map[index3]), na.rm=TRUE)
    map_expect[index3] <- Average
    map_expect[index4] <- Average
  }
  
  map <- ifelse(map_expect == 0, NA, log2(map / map_expect))
  rm(map_expect)
}



CHR <- as.character(opt["chr"])
START <- as.numeric(as.character(opt["start"]))

if(CHR=="all"){
  chromosomes <- unique(as.character(LocMatrix[,1]))
  chromsome_length <- rep(0, length(chromosomes))
  names(chromsome_length) <- chromosomes
  for(c in chromosomes){
    chromsome_length[c] <- max(as.numeric(LocMatrix[as.character(LocMatrix[,1]) == c,3]))
  }
  # chromosomes.sort <- sort(chromsome_length, decreasing = TRUE)
  Region <- c()
  LINE_for_chromosome_border <- c()
  # for(c in names(chromosomes.sort)){
  for(c in chromosomes){
    Region <- c(Region, r[as.character(LocMatrix[,1]) == c])
    LINE_for_chromosome_border <- c(LINE_for_chromosome_border, sum(as.character(LocMatrix[,1]) == c))
  }
  map.extract <- map[Region, Region]
}else{
  if(as.character(opt["end"]) == "all"){
    SameChromosome <- which(as.character(LocMatrix[,1]) == CHR)
    END <- max(as.numeric(LocMatrix[SameChromosome,3]));
  }else{
    END <- as.numeric(as.character(opt["end"]))
  }
  Region <- which((as.character(LocMatrix[,1]) == CHR) & (as.numeric(LocMatrix[,3]) >= START) & (as.numeric(LocMatrix[,2]) <= END))
  
  if(length(Region) < 5){
    cat(paste0("target region are too small. Probably too small area were specified.", CHR, ":", START, "-", END, "\n"))
    q()
  }
  
  if(as.character(opt["chr2"]) != "NULL"){
    CHR2 <- as.character(opt["chr2"])
  }else{
    CHR2 <- CHR
  }
  if(as.character(opt["start2"]) != "NULL"){
    START2 <- as.numeric(as.character(opt["start2"]))
  }else{
    START2 <- START
  }
  if(as.character(opt["end2"]) == "all"){
    SameChromosome <- which(as.character(LocMatrix[,1]) == CHR2)
    END2 <- max(as.numeric(LocMatrix[SameChromosome,3]));
  }else if(as.character(opt["end2"]) != "NULL"){
    END2 <- as.numeric(as.character(opt["end2"]))
  }else{
    END2 <- END
  }
  Region2 <- which((as.character(LocMatrix[,1]) == CHR2) & (as.numeric(LocMatrix[,3]) >= START2) & (as.numeric(LocMatrix[,2]) <= END2))
  
  if(length(Region2) < 5){
    cat(paste0("target region are too small. Probably too small area were specified.", CHR2, ":", START2, "-", END2, "\n"))
    q()
  }
  
  map.extract <- map[Region, Region2]
}

# blur image
if(eval(parse(text=opt["blur"]))){
  suppressWarnings(suppressMessages(library("spatstat")))
  c1 <- colnames(map.extract)
  c2 <- rownames(map.extract)
  t <- blur(as.im(map.extract), sigma=.6, bleed=FALSE)
  map.extract <- t$v
  rm(t)
  colnames(map.extract) <- c1
  rownames(map.extract) <- c2
}

# Gaussian smoothing
if(eval(parse(text=opt["gaus_smooth"]))){
  ### weight matrices for Gaussian smoothing
  gause_weight <- data.frame(
    V1 = c(1, 4, 7, 4, 1),
    V2 = c(4, 16, 26, 16, 4),
    V3 = c(7, 26, 41, 26, 7),
    V4 = c(4, 16, 26, 16, 4),
    V5 = c(1, 4, 7, 4, 1)
  )
  gause_weight <- as.matrix(gause_weight)
  gause_index <- which(gause_weight>0, arr.ind = TRUE)
  
  map_new <- map.extract
  map_new[,] <- 0
  for (i in 3:(nrow(map.extract)-2)){
    for (j in 3:(nrow(map.extract)-2)){
      map_index <- cbind(gause_index[,1] + i - 3, gause_index[,2] + j - 3)
      map_new[map_index] <- map_new[map_index] + map.extract[i,j] * gause_weight / 273
    }
  }
  map.extract <- map_new
  rm(map_new)
}

# moving average
N_moving_average <- as.numeric(as.character(opt["moving_average"]))
if(N_moving_average > 0){
  map_new <- map.extract
  for (i in (1:(nrow(map.extract)))){
    for (j in (1:(ncol(map.extract)))){
      map_new[i,j] = mean(map.extract[max(1,i-N_moving_average):min(nrow(map.extract),i+N_moving_average),
                                      max(1,j-N_moving_average):min(ncol(map.extract),j+N_moving_average)], na.rm = TRUE)
    }
  }
  map.extract <- map_new
  rm(map_new)
}


if(as.character(opt["unit"]) == "p"){
  NUM <- sort(as.numeric(map.extract), na.last = NA)
  if(as.character(opt["min"]) == "NULL"){
    Min <- min(map.extract, na.rm=TRUE)
  }else{
    pct <- as.numeric(as.character(opt["min"]))
    if(pct > 1){
      pct <- pct / 100
    }
    rank <- round(length(NUM)*pct)
    if(rank == 0){
      rank = rank +1
    }
    Min <- NUM[rank]
  }
  if(as.character(opt["max"]) == "NULL"){
    Max <- max(map.extract, na.rm=TRUE)
  }else{
    pct <- as.numeric(as.character(opt["max"]))
    if(pct > 1){
      pct <- pct / 100
    }
    rank <- round(length(NUM)*pct)
    if(rank == 0){
      rank = rank +1
    }
    Max <- NUM[rank]
  }
}else if(as.character(opt["unit"]) == "v"){
  if(as.character(opt["min"]) == "NULL"){
    Min <- min(map.extract, na.rm=TRUE)
  }else{
    Min <- as.numeric(as.character(opt["min"]))
  }
  if(as.character(opt["max"]) == "NULL"){
    Max <- max(map.extract, na.rm=TRUE)
  }else{
    Max <- as.numeric(as.character(opt["max"]))
  }
}


# Replace Na
if(as.character(opt["na"]) == "min"){
  MinValue <- min(map.extract, na.rm=TRUE)
  map.extract <- ifelse(is.na(map.extract), MinValue, map.extract)
}else if(as.character(opt["na"]) == "zero"){
  map.extract <- ifelse(is.na(map.extract), 0, map.extract)
}else if(as.character(opt["na"]) == "ave"){
  index <- which(is.na(map.extract), arr.ind = TRUE)
  if(length(index) > 0){
    index <- index[index[,1] != 1 & index[,1] != nrow(map.extract) & index[,2] != 1 & index[,2] != ncol(map.extract),]
    estimateNa <- function(x, y){
      v <- mean(c(map.extract[x-1,y+1], map.extract[x+1,y-1]))
      if(is.na(v)){
        v <- mean(c(map.extract[x-1,y], map.extract[x+1,y]))
      }
      if(is.na(v)){
        v <- mean(c(map.extract[x,y+1], map.extract[x,y-1]))
      }
      map.extract[x,y] <<- v
    }
    dummy <- mapply(estimateNa, as.integer(index[,1]), as.integer(index[,2]))
  }
}

# Replace 0
if(as.character(opt["zero"]) == "min"){
  tmp <- map.extract[map.extract != 0]
  MinValue <- min(tmp, na.rm=TRUE)
  map.extract <- ifelse(map.extract ==0, MinValue, map.extract)
}else if(as.character(opt["zero"]) == "ave"){
  index <- which(map==0, arr.ind = TRUE)
  if(length(index) > 0){
    index <- index[index[,1] > 1 & index[,1] < nrow(map.extract) & index[,2] > 1 & index[,2] < ncol(map.extract),]
    estimateZero <- function(x, y){
      map.extract[x,y] <<- mean(c(map.extract[x-1,y+1], map.extract[x+1,y-1]))
    }
    dummy <- mapply(estimateZero, as.integer(index[,1]), as.integer(index[,2]))
  }
}


if(as.character(opt["matrix"]) != "NULL"){
  write.table(map.extract, file=as.character(opt["matrix"]), quote=FALSE, sep="\t", eol="\n", row.names=TRUE, col.names=NA)
}

map.conv <- TakeMiddleV(map.extract, Min, Max)

### Only draw half
if(eval(parse(text=as.character(opt["triangle"])))){
  half <- lower.tri(map.conv, diag=TRUE)
  map.conv[half] <- NA
}


if(as.character(opt["width"]) == "NULL"){
  width <- nrow(map)
}else{
  width <- as.numeric(as.character(opt["width"]))
}

if(as.character(opt["height"]) == "NULL"){
  height <- width / ncol(map.conv) * nrow(map.conv)
}else{
  height <- as.numeric(as.character(opt["height"]))
}


lseq <- function(from=1, to=100000, length.out=6) {
  if(from == to){
    from
  }else{
    exp(seq(log(from), log(to), length.out = length.out))
  }
}



# Adjust the color
if(eval(parse(text=opt["linerColor"]))){
  bk <- seq(Min, Max, length.out=100)
}else{
  # t <- (Max - Min) * 0.7 + Min
  # bk <- unique(c(seq(Min, t, length.out=80), lseq(t, Max, length.out = 30), Max+1))
  tmp <- as.numeric(map.conv)
  tmp <- tmp[!is.na(tmp)]
  T95 <- sort(tmp)[round(length(tmp)*0.95)]
  bk <- unique(c(seq(Min, T95, length.out=95), lseq(T95, Max+1, length.out=5)), digits=2)
}

# t <- (Max - Min) * 0.8 + Min
# bk <- unique(round(c(seq(Min, t, length.out=90), lseq(t, Max+1, length.out = 10)), digits = 2))
map.cat <- matrix(as.integer(cut(map.conv, breaks = bk, include.lowest = TRUE)), nrow = nrow(map.conv))
colors <- colorRampPalette(pallete)(length(bk))
colors <- colors[min(map.cat, na.rm=TRUE):max(map.cat, na.rm=TRUE)]

FILE_OUT <- as.character(opt["out"])
png(file=FILE_OUT, width=width, height=height, units="px", bg="white")
par(oma=c(0,0,0,0), mar=c(0,0,0,0))
image(Transform(map.cat), col=colors, axes=F)


if(as.character(opt["linev_chr"])!="NULL"){
  for(M in unlist(strsplit(as.character(opt["linev_pos"]), ","))){
    line <- as.numeric(gsub(" ", "", M, fixed = TRUE))
    L1 <- which((LocMatrix[,1] == as.character(opt["linev_chr"])) & (as.numeric(LocMatrix[,2]) <= line) & (as.numeric(LocMatrix[,3]) >= line))
    target <- (L1 - min(Region)) / (length(Region)-1)
    abline(h=(1-target), col=adjustcolor("chartreuse4", alpha.f = 0.5), lty=3, lwd=5)
  }
}
if(as.character(opt["lineh_chr"])!="NULL"){
  for(M in unlist(strsplit(as.character(opt["lineh_pos"]), ","))){
    line <- as.numeric(gsub(" ", "", M, fixed = TRUE))
    L2 <- which((LocMatrix[,1] == as.character(opt["lineh_chr"])) & (as.numeric(LocMatrix[,2]) <= line) & (as.numeric(LocMatrix[,3]) >= line))
    target <- (L2 - min(Region2)) / (length(Region2)-1)
    abline(v=target, col=adjustcolor("sienna4", alpha.f = 0.5), lty=3, lwd=5)
  }
}
if(CHR=="all"){
  Location <- cumsum(LINE_for_chromosome_border[1:(length(LINE_for_chromosome_border)-1)])/nrow(map)
  abline(v=Location, col="black", lty=1, lwd=2)
  abline(h=1-Location, col="black", lty=1, lwd=2)
}

if(as.character(opt["circle"]) != "NULL"){
  DATA_circle <- read.table(as.character(opt["circle"]), header=F, sep="\t", check.names = F)
  nc <- colnames(map.extract)
  nr <- rownames(map.extract)
  OK_pair <- DATA_circle[,1] %in% nr & DATA_circle[,2] %in% nc
  DATA_circle <- DATA_circle[OK_pair,]
  for(i in 1:nrow(DATA_circle)){
    par(new=T)
    plot(which(DATA_circle[i,1] == nr), nrow(map.extract) - which(DATA_circle[i,2] == nc)+1, pch=21, xlim=c(1,ncol(map.extract)), 
         ylim=c(1,nrow(map.extract)), xaxs="i", yaxs="i", cex=2, axes=F, col='black', lwd=2.5)
  }
}

dummy <- dev.off()


