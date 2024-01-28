# Process Hi-C bias (ICE2) input data.frame with limited distance

suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="input normalized data"),
  make_option(c("-o", "--out"),help="Normalized matrix file"),
  make_option(c("--log"), default="NA", help="log file"),
  make_option(c("--times"), default="30", help="how many times apply normalization"),
  make_option(c("-t", "--threshold"), default=0.02, help="cut off threshold (default 0.02). Line with less than this value will remove.
                Value with less than 10 will be considered as %."),
  make_option(c("-q", "--quiet"), default="FALSE", help="don't output log")
)
opt <- parse_args(OptionParser(option_list=option_list))

suppressWarnings(suppressMessages(library(data.table)))
suppressWarnings(suppressMessages(library(dplyr)))

options(dplyr.summarise.inform = FALSE)

FILE_in <- as.character(opt["in"])
FILE_out <- as.character(opt["out"])
Threshold <- as.numeric(as.character(opt["threshold"]))
FLAG_quiet <- as.character(opt["quiet"])


if(as.character(opt["log"]) == "NA"){
  FILE_log <- sub(".txt", ".log", FILE_out)
}else{
  FILE_log <- as.character(opt["log"])
}


D_table <- fread(FILE_in, header = T)

D_line <- rbind(D_table %>% select(loc=loc1, score), D_table %>% filter(loc2!='long_distance') %>% select(loc=loc2, score))
D_line <- D_line %>% group_by(loc) %>% summarize(zero_rate = sum(score==0 || is.na(score)) / length(score)) %>% ungroup()
D_line <- D_line %>% mutate(ok=ifelse((1 - zero_rate) > Threshold, 1, 0))

D_table <- dplyr::left_join(D_table, D_line %>% select(loc1=loc, ok1=ok), by="loc1")
D_table <- dplyr::left_join(D_table, D_line %>% select(loc2=loc, ok2=ok), by="loc2")
rm(D_line)

D_long <- D_table %>% filter(loc2=='long_distance', ok1==1, !is.na(score)) %>% select(loc=loc1, long=score)
D_table <- D_table %>% filter(loc2!='long_distance', ok1==1, ok2==1, !is.na(score)) %>% select(loc1, loc2, score)
D_table <- rbind(D_table %>% filter(loc1!=loc2), D_table %>% dplyr::rename(loc1=loc2, loc2=loc1))
D_table <- D_table %>% group_by(loc1, loc2) %>% summarise(score=sum(score)) %>% ungroup()

Single <- function(m, b){
  Db <- m %>% group_by(loc1) %>% summarize(Lscore=sum(score, na.rm = T)) %>% ungroup()
  
  Average_of_B <- b %>% filter(bias!=0, !is.na(bias)) %>% pull(bias) %>% mean()
  Db <- dplyr::left_join(Db %>% select(loc=loc1, Lscore), b, by="loc")
  Db <- dplyr::left_join(Db, D_long, by="loc")
  Db <- Db %>% mutate(bias=ifelse(is.na(bias), 1, bias), long=ifelse(is.na(long), 0, long))
  Db <- Db %>% mutate(Lscore=Lscore+long/(bias/Average_of_B))
  
  Average_of_Db <- Db %>% filter(!is.na(Lscore)) %>% pull(Lscore) %>% mean()
  Db <- Db %>% mutate(Lscore = Lscore / Average_of_Db)
  Db <- Db %>% mutate(Lscore = ifelse(Lscore == 0, 1, Lscore))
  
  m <- dplyr::left_join(m, Db %>% select(loc1=loc, Lscore.L = Lscore), by="loc1")
  m <- dplyr::left_join(m, Db %>% select(loc2=loc, Lscore.R = Lscore), by="loc2")
  m <- m %>% mutate(score = score / Lscore.L / Lscore.R)
  m <- m %>% select(loc1, loc2, score)
  
  list(map=m, bias=Db %>% select(loc, Lscore))
}


multi <- function(m, times){
  B <- D_long %>% mutate(bias=1) %>% select(loc, bias)

  # Get initial variance
  initial_var <- m %>% group_by(loc1) %>% summarize(Lscore=sum(score, na.rm = T)) %>% ungroup()
  initial_var <- dplyr::left_join(initial_var %>% select(loc=loc1, Lscore), D_long, by="loc")
  initial_var <- initial_var %>% mutate(Lscore=Lscore + long)
  Average_of_initial_var <- initial_var %>% filter(Lscore != 0) %>% pull(Lscore) %>% mean()
  initial_var <- initial_var %>% mutate(Lscore = ifelse(Lscore == 0, 1, Lscore / Average_of_initial_var))

  initial_var <- var(initial_var %>% filter(!is.na(Lscore)) %>% pull(Lscore))
  
  if(FLAG_quiet == "FALSE"){
    cat("Variance at 0 times:\t", initial_var, "\n", sep="", file = FILE_log, append = TRUE)
  }
  
  for(i in 1:times){
    S <- Single(m, B)
    m <- S$map
    B <- dplyr::left_join(B, S$bias, by="loc")
    B <- B %>% mutate(bias = bias * Lscore) %>% select(-Lscore)
    if(FLAG_quiet == "FALSE"){
      step_var <- var(S$bias %>% filter(!is.na(Lscore)) %>% pull(Lscore))
      cat("Variance at ", i, " times:\t", step_var, "\n", sep="", file = FILE_log, append = TRUE)
    }
  }
  m
}

options(warn=-1)
TIMES_apply <- as.numeric(as.character(opt["times"]))
D_table <- multi(D_table, TIMES_apply)
D_table <- D_table %>% mutate(L1=loc1, L2=loc2)
D_table <- D_table %>% tidyr::separate(L1, c("chr1", "start1", "end1"), ":", convert=TRUE, extra="merge")
D_table <- D_table %>% tidyr::separate(L2, c("chr2", "start2", "end2"), ":", convert=TRUE, extra="merge")
D_table <- D_table %>% filter(start1 <= start2)
D_table <- D_table %>% select(loc1, loc2, score)
D_table$score <- as.numeric(format(D_table$score, digits = 5))

write.table(D_table, FILE_out, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)


