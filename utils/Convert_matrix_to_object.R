# Create .rds R object file from matrix file


suppressPackageStartupMessages(library("optparse"))
option_list <- list(  
  make_option(c("-i", "--in"),help="Matrix file"),
  make_option(c("-o", "--out"), default="NA", help="output rds file")
)
opt <- parse_args(OptionParser(option_list=option_list))

FILE_matrix <- as.character(opt["in"])
FILE_object <- as.character(opt["out"])
if(FILE_object == "NA"){
  FILE_object <- sub(".matrix", ".rds", FILE_matrix)
}

map <- as.matrix(read.table(FILE_matrix, header=TRUE, check.names = FALSE))
saveRDS(map, FILE_object)

system(paste("gzip", FILE_matrix))




