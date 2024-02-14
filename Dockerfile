# Build dependencies
FROM perl:5.30.0 AS perl_build
FROM nouchka/sqlite3:latest AS sqlite3_build
FROM biocontainers/fastqc:v0.11.9_cv8 AS fastqc_build
FROM biocontainers/bowtie2:v2.4.1_cv1 AS bowtie2_build
FROM staphb/samtools:1.19 AS samtools_build
FROM r-base:4.0.2 AS R_build

COPY --from=perl_build /usr/local/bin/perl /usr/local/bin/perl
COPY --from=perl_build /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=sqlite3_build /usr/bin/sqlite3 /usr/bin/sqlite3
RUN mkdir -p /root/db
COPY --from=fastqc_build /usr/local/bin/fastqc /usr/local/bin/fastqc
COPY --from=fastqc_build /usr/bin/java /usr/bin/java
COPY --from=bowtie2_build /home/biodocker/bin /software/bowtie2
ENV PATH=/software/bowtie2:$PATH

# Copy current repo and set working directory
COPY . /app
WORKDIR /app

# Install required R libraries
RUN Rscript /app/install_libraries.R

# Print out environment variable information
RUN env
