# rfy_hic2
Hi-C processing pipeline

# Citation

If you use `rfy_hic2` in your research, please cite the following paper:

Tanizawa, H. et al. *Step-by-Step Protocol to Generate Hi-C Contact Maps Using the rfy_hic2 Pipeline*. **Methods Mol Biol** 2856, 133–155 (2025).  
[PubMed](https://pubmed.ncbi.nlm.nih.gov/39283450/) | [DOI: 10.1007/978-1-0716-4136-1_8](https://link.springer.com/protocol/10.1007/978-1-0716-4136-1_8)

# Hardware Requirement
This pipeline is designed for use in a Linux environment, while it can also be run in other operation systems given suitable setup. Windows users can use the pipe-line by installing the Windows Subsystem for Linux (WSL). While macOS and Linux are both UNIX-like op-eration systems, it is important to note that macOS users might encounter unex-pected command behaviors. To provide broad compatibility while acknowledging potential limitations for non-Linux operating systems.

Given the software prerequisites and the need to process large text files, a Linux system with at least a dual-core CPU and 4GB of RAM is required. For a more comfortable analysis experience, an 8-core CPU and 32GB of RAM are recommended to ensure efficient pipeline execution.

# Software Prerequisites
The following software is required to execute the pipeline rfy_hic2. The versions listed in parentheses are those used for verification dur-ing the creation of this protocol.
+ Git (version 2.34.1) – A distributed version control system with speed and ef-ficiency. https://git-scm.com/
+ Bash (version 5.1.16) - A Unix shell and command language. https://www.gnu.org/software/bash/
+ FastQC (version 0.11.9) - A quality control tool for high throughput sequence data. https://www.bioinformatics.babraham.ac.uk/projects/fastqc/
+ Samtools (version 1.13) - A suite of programs for interacting with high-throughput sequencing data. https://www.htslib.org/
+ SQLite3(version 3.37.2) - A C-language library that implements a small, fast, self-contained, high-reliability, full-featured SQL database engine.  https://www.sqlite.org/
+ R (version 4.1.2) - A software environment for statistical computing and graphics. For installation examples. https://www.r-project.org/
+ Perl (version 5.34.0) - A competent, feature-rich programming language with over 30 years of development. https://www.perl.org/
+ SRA-Toolkit (version 3.0.10) - A collection of tools and libraries for using da-ta in the Sequence Read Archives. https://github.com/ncbi/sra-tools
+ Bowtie2 (version 2.4.4) - An ultrafast and memory-efficient tool for aligning sequencing reads to long reference sequences. https://bowtie-bio.sourceforge.net/bowtie2/

# Genome Sequence
Download the reference genome in FASTA format to initiate the analysis. For fission yeast (Schizosaccharomyces pombe), the reference genome is available at the PomBase (https://www.pombase.org) 
Simplify the download and organization of the main three chromosomes (I, II, and III) with the following script:
```
cd ${GENOME_DIR}
for CHR in I II III
do
curl -O https://www.pombase.org/data/genome_sequence_and_features/genome_sequence/Schizosaccharomyces_pombe_chromosome_${CHR}.fa.gz
done
```
Next, combine these chromosome files into one comprehensive file using:
```
zcat Schizosaccharomyces_pombe_chromosome_*.fa.gz  > all.fa
```
Finally, calculate the length of each chromosome using the “samtools faidx” command as follows:
```
samtools faidx all.fa
```
Executing the above command will generate a file named “all.fa.fai”. This file contains a list of all chromosomes included in “all.fa” along with their length information.

# Index File for Bowtie2
To align sequencing reads using Bowtie2, indexing a reference FASTA file is nec-essary. This process is accomplished using the “bowtie2-build” command as fol-lows:
```
cd ${GENOME_DIR}
bowtie2-build -f all.fa <INDEX_NAME>
```

# Test dataset
Test data can be download from using the following address:
+ https://www.igm.hokudai.ac.jp/gacha/data/test_1.fastq.gz
+ https://www.igm.hokudai.ac.jp/gacha/data/test_2.fastq.gz

Those files were the first 5 million reads from Hi-C data of fission yeast genome during the cell cycle process. The full datasets can be accessed from the Gene Expression Omnibus (GEO) using the accession number GSE93198 (https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE93198).

# Install guide
To set up the Hi-C automation pipeline, begin by downloading the rfy_hic2 using the command provided below. 
```
git clone https://github.com/rafysta/rfy_hic2.git
```
Next, to install the necessary R packages for execution, run “in-stall_libraries.R” :
```
Rscript --vanilla --no-echo install_libraries.R
```
After installing the all required software, ensure it is operational by performing an environment check:
```
bash rfy_hic2.sh --env_check
```
If error messages appear, it indicates that not all required software is excutable from the program. In such cases, either install the missing software or add the folder path containing the executable software to the execution path variable.

# Instructions for use
The Hi-C data processing pipeline features two primary components: the automated matrix creation and visualization. Initially, it begins with sequencing reads, advances to alignment with the reference genome, incorporates various filtering steps, and ultimately generates a matrix in the automation section. The subsequent visualization segment employs this matrix to produce a heatmap illustrating Hi-C genomic contacts. 
![Flow chart of processing pipeline](img/automated_pipeline.jpg?raw=true "Flow chart")

The automation section includes five distinct programs capable of autonomously conducting the entire procedure. This is achieved by setting all pa-rameters in a configuration file (“argfile”), a plain text document that lists the re-quired parameter values for each stage of the analysis. After preparing the argfile, it is passed as a command-line argument to initiate the automated procedure in the following manner:
```
bash rfy_hic2.sh --arg <argfile>
```
An example argfile, “argfile_default.env”, is provided in the rfy_hic2 pipeline to illustrate the pipeline configuration. Despite the “.env” extension, the content is in plain text format. To match the environment, it is necessary to amend the content, especially the full paths for each directory.

Upon editing, execute the command as follows:
```
bash rfy_hic2.sh --arg ${DIR_OUT}/argfile_projectA.env
```
The configuration file is applicable even when executing individual stages eparately. Furthermore, a “--help” option is available for all subsequent pro-grams, including rfy_hic2.sh. For instance, executing:
```
bash rfy_hic2.sh --help
```
allows verification of necessary parameters for command execution. 


