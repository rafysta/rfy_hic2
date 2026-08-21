# Shared setting files (examples)

Copy this directory to e.g. `${HOME}/Genome/config/` and edit the paths.
A sample argfile then only needs to `source` the relevant files:

```bash
set -a
source ${HOME}/Genome/config/talapas_modules.env   # cluster environment (optional)
source ${HOME}/Genome/config/pombe.env             # genome
source ${HOME}/Genome/config/pombe_MboI.env        # restriction enzyme
source ${PROJECT}/config/project.env               # project defaults (DIR_DATA, RESOLUTIONs, ...)
NAME=sample01
FILE_fastq1=/path/to/sample01_R1.fastq.gz
FILE_fastq2=/path/to/sample01_R2.fastq.gz
set +a
```

`LENGTH.txt` / `all.fa.fai` must be a tab separated file whose first two
columns are chromosome name and length (`samtools faidx all.fa` output works).
