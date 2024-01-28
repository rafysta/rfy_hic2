# Create .rds R object file from matrix file


suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="Matrix file"),
  make_option(c("-o", "--out"), default="NA", help="output rds file")
)
opt <- parse_args(OptionParser(option_list=option_list))

suppressWarnings(suppressMessages(library(data.table)))

FILE_in <- as.character(opt["in"])
FILE_out <- as.character(opt["out"])

df <- as.data.frame(fread(FILE_in, header=TRUE))
saveRDS(df, FILE_out)

system(paste("gzip", FILE_in))




