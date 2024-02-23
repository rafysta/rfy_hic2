#!/bin/bash
# Making map file


get_usage(){
	cat <<EOF

Usage : $0 [OPTION]

Description
	-h, --help
		show help

	-v, --version
		show version

	--arg [setting file]
		parameter setting file

	-d, --directory [data directory]
		directory name of analysis file locate

	-n, --name [sample name]
		sample name

	--f1 [fastq file(s)]
		Comma-separated list of compressed fastq to be aligned
	
	--f2 [fastq file(2)]
		Comma-separated list of compressed fastq to be aligned

	-t, --threshold [threshold. default: 10000]
		threshold to remove different direction reads to remove potential self ligation. (default 10kb)
		We use 2kb for 3 restriction enzyme Hi-C

	-q, --fastqc
		TRUE for doing fastqc analysis or FALSE for not doing (default FALSE)

	--tmp
		directory to store temporary file. (default /tmp)

	--verbose
		Output bowtie2 trimming alignment log
EOF

}

get_version(){
	echo "bash ${0} version 2.0"
}

SHORT=hvd:n:t:q:
LONG=help,version,arg:,directory:,name:,f1:,f2:,threshold:,fastqc:,tmp:,verbose
PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? -ne 0 ]]; then
	exit 2
fi
eval set -- "$PARSED"

while true; do
	case "$1" in
		-h|--help)
			get_usage
			exit 1
			;;
		-v|--version)
			get_version
			exit 1
			;;
		--arg)
			FILE_ARG="$2"
			shift 2
			;;
		-d|--directory)
			DIR_DATA="$2"
			shift 2
			;;
		-n|--name)
			NAME="$2"
			shift 2
			;;
		--f1)
			FILE_fastq1="$2"
			shift 2
			;;
		--f2)
			FILE_fastq2="$2"
			shift 2
			;;
		-q|--fastqc)
			FLAG_fastqc="$2"
			shift 2
			;;
		-t|--threshold)
			THRESHOLD_SELF="$2"
			shift 2
			;;
		--tmp)
			DIR_tmporary="$2"
			shift 2
			;;
		--verbose)
			VERBOSE=TRUE
			shift
			;;
		--)
			shift
			break
			;;
		*)
			echo "Programming error"
			exit 3
			;;
	esac
done

DIR_LIB=$(dirname $0)
TIME_STAMP=$(date +"%Y-%m-%d")

#-----------------------------------------------
# Load setting
#-----------------------------------------------
[ ! -n "${FILE_ARG}" ] && source ${FILE_ARG}

command -v bowtie2 >/dev/null 2>&1 || echo "bowtie2 command is not available. Please install it or add its path to the $PATH environment variable."
command -v samtools >/dev/null 2>&1 || echo "samtools command is not available. Please install it or add its path to the $PATH environment variable."

[ ! -n "${NAME}" ] && echo "Please specify NAME" && exit 1
[ ! -n "${DIR_DATA}" ] && echo "Please specify data directory" && exit 1
[ ! -n "${FILE_fastq1}" ] && echo "Please specify fastq file1" && exit 1
[ ! -n "${FILE_fastq2}" ] && echo "Please specify fastq file2" && exit 1
FLAG_fastqc=${FLAG_fastqc:-FALSE}
VERBOSE=${VERBOSE:-FALSE}
DIR_tmporary=${DIR_tmporary:-"/tmp"}
THRESHOLD_SELF=${THRESHOLD_SELF:-10000}

cd ${DIR_DATA}

#-----------------------------------------------
# Alignment
#-----------------------------------------------
export BOWTIE2_INDEX DIR_DATA VERBOSE
export FILE_fastq=${FILE_fastq1} OUT=${NAME}_1 DIR_tmporary=${DIR_tmporary}
bash ${DIR_LIB}/utils/Alignment_with_trimming.sh
[ $? -ne 0 ] && exit 1

export FILE_fastq=${FILE_fastq2} OUT=${NAME}_2 DIR_tmporary=${DIR_tmporary}
bash ${DIR_LIB}/utils/Alignment_with_trimming.sh
[ $? -ne 0 ] && exit 1

#-----------------------------------------------
# fastqc
#-----------------------------------------------
if [ "$FLAG_fastqc" = "TRUE" ]; then
	[ ! -e "${DIR_DATA}/fastqc" ] && mkdir "${DIR_DATA}/fastqc"
	fastqc -o fastqc/ --nogroup -t 12 $(echo ${FILE_fastq1} | tr ',' ' ')
	fastqc -o fastqc/ --nogroup -t 12 $(echo ${FILE_fastq2} | tr ',' ' ')
fi


#-----------------------------------------------
# assign to nearest restriction enzyme site
#-----------------------------------------------
# "-" direction => shift align position + read length 
# Repeat or Unique was categorized based on the tag "XS:i"
perl ${DIR_LIB}/utils/Assign_nearest_enzymeSites.pl -a ${NAME}_1.sam -b ${NAME}_2.sam -o ${NAME}.map -e ${FILE_enzyme_def} -d ${FILE_enzyme_index} > ${NAME}_alignment.log
[ $? -ne 0 ] && echo "Assign to nearest restirction enzyme site was failed" && exit 1

#-----------------------------------------------
# Extract unique map file and register to database
#-----------------------------------------------
# swap left and right to make left side always smaller than right
# if restriction sites were missing, remove those pairs
# entire chromosome were roughly split to 100 and split map file based 
perl ${DIR_LIB}/utils/Split_MapFile.pl -i ${NAME}.map -l ${CHROM_LENGTH} -o ${NAME}_list.txt
[ $? -ne 0 ] && echo "Split mapfile was failed" && exit 1
cat ${NAME}_list.txt | xargs -P12 -I@ bash -c "sort -k2,2 -k3,3n -k9,9 -k10,10n @ | awk -v OFS='\t' '{print \$0,\$2,\$3,\$9,\$10}' | uniq -f 15 | cut -f1-15 > @_sorted && mv @_sorted @"
echo "id,chr1,position1,direction1,mapQ1,restNum1,restLoc1,uniq1,chr2,position2,direction2,mapQ2,restNum2,restLoc2,uniq2" | tr ',' '\t' > ${NAME}.map
cat $(cat ${NAME}_list.txt) >> ${NAME}.map
rm $(cat ${NAME}_list.txt) ${NAME}_list.txt
Rscript --vanilla --no-echo ${DIR_LIB}/utils/file2database_large.R -i ${NAME}.map --db ${NAME}.db --table map
MAP_SIZE=$(head -n 1000 ${NAME}.map | wc -l)
if [ $MAP_SIZE -eq 1000 ];then
	gzip ${NAME}.map
	rm ${NAME}_1.sam ${NAME}_2.sam
else
	echo "Map generation was failed"
	exit 1
fi

#-----------------------------------------------
# Summarize read filtering
#-----------------------------------------------
export DIR_DATA SAMPLE=${NAME} THRESHOLD_SELF=${THRESHOLD_SELF}
bash ${DIR_LIB}/utils/Count_reads.sh > ${NAME}_read_filtering.log



#-----------------------------------------------
# DNA amount estimation
#-----------------------------------------------
perl ${DIR_LIB}/utils/Count_DNA_amount.pl -i ${NAME}.db -o ${NAME}_DNA_amount.bed

