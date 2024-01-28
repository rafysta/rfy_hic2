#!/bin/bash
# make fragment database

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

	-i, --in [map files. ex. name1.map.gz,name2.map.gz]
		map file. separated by comma. it could be gzipped.

	-n, --name [sample name]
		sample name

	-m, --mapq [mapq threshold (default:30)]
		threshold mapQ to make map

	-t, --threshold [threshold. default: 10000]
		threshold to remove different direction reads to remove potential self ligation. (default 10kb)
		We use 2kb for 3 restriction enzyme Hi-C

	--remove
		remove all output files
EOF

}

get_version(){
	echo "${0} version 2.0"
}

SHORT=hvd:i:n:m:t:
LONG=help,version,arg:,directory:,in:,name:,mapq:,threshold:,remove
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
		-i|--in)
			FILE_MAPs="$2"
			shift 2
			;;
		-n|--name)
			NAME="$2"
			shift 2
			;;
		-m|--mapq)
			MAPQ_THRESHOLD="$2"
			shift 2
			;;
		-t|--threshold)
			THRESHOLD_SELF="$2"
			shift 2
			;;
		--remove)
			FLAG_remove="TRUE"
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
INPUT_FILES=$@


#-----------------------------------------------
# Load setting
#-----------------------------------------------
[ ! -n "${FILE_ARG}" ] && source ${FILE_ARG}

[ ! -n "${DIR_DATA}" ] && echo "Please specify data directory" && exit 1
[ ! -n "${FILE_MAPs}" ] && echo "Please specify input map files" && exit 1
[ ! -n "${NAME}" ] && echo "Please specify NAME" && exit 1
MAPQ_THRESHOLD=${MAPQ_THRESHOLD:-30}
FLAG_remove=${FLAG_remove:-FALSE}
THRESHOLD_SELF=${THRESHOLD_SELF:-10000}

cd ${DIR_DATA}

#-----------------------------------------------
# Remove all output file
#-----------------------------------------------
if [ $FLAG_remove = "TRUE" ]; then
	rm ${NAME}_fragment_pair.txt.gz ${NAME}_distance.txt ${NAME}_DNA_amount.bed ${NAME}_bad_fragment.txt ${NAME}_fragment.png ${NAME}_fragment.db ${NAME}_fragment.txt ${NAME}_InterChromosome.matrix
	exit
fi


#-----------------------------------------------
# Split map files after filtering
#-----------------------------------------------
perl ${DIR_LIB}/utils/Split_database.pl -l ${CHROM_LENGTH} -o ${NAME}_list.txt -m ${MAPQ_THRESHOLD} -e ${FILE_enzyme_def} -i ${FILE_MAPs} -t ${THRESHOLD_SELF}
cat ${NAME}_list.txt | xargs -P12 -I@ sh -c "sort -k1,1 -k2,2n -k5,5 -k6,6n @ | uniq -c | awk -v OFS='\t' '{print \$2,\$3,\$4,\$5,\$6,\$7,\$8,\$9,\$1}' > @_counted && mv @_counted @"
echo "chr1,start1,end1,fragNum1,chr2,start2,end2,fragNum2,score" | tr ',' '\t' > ${NAME}_fragment_pair.txt
cat $(cat ${NAME}_list.txt) >> ${NAME}_fragment_pair.txt
rm $(cat ${NAME}_list.txt) ${NAME}_list.txt
Rscript --vanilla --no-echo ${DIR_LIB}/utils/file2database_large.R -i ${NAME}_fragment_pair.txt --db ${NAME}_fragment.db --table fragment
gzip ${NAME}_fragment_pair.txt


#-----------------------------------------------
# Distance curve
#-----------------------------------------------
sh ${DIR_LIB}/utils/Distance_curve.sh -i ${NAME}.map.gz -o ${NAME}_distance.txt

#-----------------------------------------------
# Fragment property
#-----------------------------------------------
perl ${DIR_LIB}/utils/Fragment_property.pl -i ${NAME}_fragment.db > ${NAME}_fragment.txt
Rscript --vanilla --no-echo ${DIR_LIB}/utils/Define_bad_fragment_threshold.R -i ${NAME}_fragment.txt --png ${NAME}_fragment.png -o ${NAME}_bad_fragment.txt --name ${NAME}


#-----------------------------------------------
# Inter chromosomal association matrix
#-----------------------------------------------
perl ${DIR_LIB}/utils/Make_association_from_fragmentdb_interChromosome.pl -i ${NAME}_fragment.db -o ${NAME}_InterChromosome.matrix -b ${NAME}_bad_fragment.txt
