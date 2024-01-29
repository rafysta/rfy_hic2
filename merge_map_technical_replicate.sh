#!/bin/bash
# Merge map files from technical replicates (remove PCR duplicate)


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
		
	-i, --in [map files]
		map files. Separated with ,. Map files could be gziped

	-d, --directory [data directory]
		directory name of analysis file locate

	-n, --name [merged sample name]
		sample name after merged

	-t, --threshold [threshold. default: 10000]
		threshold to remove different direction reads to remove potential self ligation. (default 10kb)
		We use 2kb for 3 restriction enzyme Hi-C

EOF

}

get_version(){
	echo "sh ${0} version 2.0"
}

SHORT=hvi:d:n:t:
LONG=help,version,arg:,in:,directory:,name:,threshold:
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
		-i|--in)
			FILE_IN="$2"
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
		-x|--ref)
			REF="$2"
			shift 2
			;;
		-t|--threshold)
			THRESHOLD_SELF="$2"
			shift 2
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

[ ! -n "${NAME}" ] && echo "Please specify NAME" && exit 1
[ ! -n "${DIR_DATA}" ] && echo "Please specify data directory" && exit 1
[ ! -n "${FILE_IN}" ] && echo "Please specify map files for technical replicates for merging" && exit 1
THRESHOLD_SELF=${THRESHOLD_SELF:-10000}


cd ${DIR_DATA}



#-----------------------------------------------
# Merge map files
#-----------------------------------------------
NUM_MAP_file=$(echo $FILE_IN | tr ',' ' ' | xargs -n1 | wc -l)
if [ $NUM_MAP_file -eq 1 ]; then
	echo "Please specify at least 2 map files" && exit 1
else
	echo $FILE_IN | tr ',' ' ' | xargs -n1 | xargs -I@ sh -c "zcat @ | tail -n +2 " > ${NAME}.map

	perl ${DIR_LIB}/utils/Split_MapFile.pl -i ${DIR_DATA}/${NAME}.map -l ${CHROM_LENGTH} -o ${NAME}_list.txt
	[ $? -ne 0 ] && echo "Split mapfile was failed" && exit 1
	cat ${NAME}_list.txt | xargs -P12 -I@ sh -c "sort -k2,2 -k3,3n -k9,9 -k10,10n @ | awk -v OFS='\t' '{print \$0,\$2,\$3,\$9,\$10}' | uniq -f 15 | cut -f1-15 > @_sorted && mv @_sorted @"
	echo "id,chr1,position1,direction1,mapQ1,restNum1,restLoc1,uniq1,chr2,position2,direction2,mapQ2,restNum2,restLoc2,uniq2" | tr ',' '\t' > ${NAME}.map
	cat $(cat ${NAME}_list.txt) >> ${NAME}.map
	rm $(cat ${NAME}_list.txt) ${NAME}_list.txt
fi

#-----------------------------------------------
# Register to database
#-----------------------------------------------
Rscript --vanilla --no-echo ${DIR_LIB}/utils/file2database_large.R -i ${NAME}.map --db ${NAME}.db --table map
gzip ${NAME}.map

#-----------------------------------------------
# Summarize read filtering
#-----------------------------------------------
export DIR_DATA SAMPLE=${NAME} THRESHOLD_SELF=${THRESHOLD_SELF}
sh ${DIR_LIB}/utils/Count_reads.sh > ${NAME}_read_filtering.log

#-----------------------------------------------
# DNA amount estimation
#-----------------------------------------------
perl ${DIR_LIB}/utils/Count_DNA_amount.pl -i ${NAME}.db -o ${NAME}_DNA_amount.bed
