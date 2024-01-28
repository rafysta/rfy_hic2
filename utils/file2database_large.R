#!/usr/bin/Rscript
# make database for large input file

suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"), default="", help="tab file to input"),
  make_option(c("--db"), default="", help="database file"),
  make_option(c("--table"), default="table", help="table name")
)
opt <- parse_args(OptionParser(option_list=option_list))

library("RSQLite")
suppressPackageStartupMessages(require(data.table))

DB_file <- as.character(opt["db"])
if(file.exists(DB_file)){
  dummy <- file.remove(DB_file)
}
con = dbConnect(SQLite(), DB_file)

FILE_in <- as.character(opt["in"])
TALBE_NAME <- as.character(opt["table"])
NumRow=as.integer(system(paste("wc -l", FILE_in, "| sed 's/[^0-9.]*\\([0-9.]*\\).*/\\1/'"), intern=T))


DATA_head <- read.table(FILE_in, header=TRUE, nrows = 10)
COLUMN_NAMES <- colnames(DATA_head)

UNIT=10000000
r <- 1
for(i in seq(1, NumRow, UNIT)){
  if(r == 1){
    SKIP_NUM <- 1
    LINE_numbers <- min(UNIT, NumRow - i + 1)-1
  }else{
    SKIP_NUM <- i - 1
    LINE_numbers <- min(UNIT, NumRow - i + 1)
  }
  D_table <- fread(FILE_in, skip = SKIP_NUM, nrows = LINE_numbers, stringsAsFactors = FALSE, sep="\t", header=FALSE, col.names=COLUMN_NAMES)
  dbWriteTable(con, TALBE_NAME, D_table, row.names= FALSE, append = TRUE)
  r <- r+1
}
dbDisconnect(con)
