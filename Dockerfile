# Build dependencies
FROM nouchka/sqlite3:latest

RUN apt -y update && apt -y upgrade
RUN apt install -y fastqc
RUN apt install -y samtools
RUN apt install -y bowtie2
RUN apt install -y r-base

# Copy current repo and set working directory
COPY . /app
WORKDIR /app

# Install required R libraries
RUN Rscript --vanilla /app/install_libraries.R

# Print out environment variable information
RUN env
