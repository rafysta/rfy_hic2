#!/bin/bash
# random sampling of map.gz file

get_usage(){
	cat <<EOF

Usage : $0 [OPTION] xxx.map.gz

Description
	-h, --help
		show help

	-v, --version
		show version

	-n, --number [number]
		random sampling to this number

	-t, --threshold [threshold for self]
		only take same direction reads for less than this threshold (default: 10000)

	-o, --out [output file]
		output file name
EOF

}

get_version(){
	echo "${0} version 1.0"
}

SHORT=hvn:t:o:
LONG=help,version,number:,threshold:,out:
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
		-n|--number)
			T_NUMBER="$2"
			shift 2
			;;
		-t|--threshold)
			THRESHOLD="$2"
			shift 2
			;;
		-o|--out)
			FILE_out="$2"
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
TIME_STAMP=$(date +"%Y-%m-%d_%H.%M.%S")
INPUT_FILES=$@

[ ! -n "${T_NUMBER}" ] && echo "Please specify sampling number" && exit 1
[ ! -n "${FILE_out}" ] && echo "Please specify output file name" && exit 1
THRESHOLD=${THRESHOLD:-10000}


DIR_tmp=$(mktemp -d /tmp/tmp_random_sampling.XXXXXX)
[ ! -e ${DIR_tmp} ] && mkdir ${DIR_tmp}
trap "rm -r ${DIR_tmp}" 0


### output header
echo $INPUT_FILES | xargs -n1 | head -n1 | xargs zcat 2>/dev/null | head -n 1 > ${DIR_tmp}/sampled_map.txt


### filtering map
echo $INPUT_FILES | xargs -n1 | xargs -I@ sh -c "zcat @ | tail -n +2 " | awk -v OFS='\t' -v T=${THRESHOLD} -v f=${DIR_tmp}/map.txt 'BEGIN{
	TOTAL_READ=0;
}$8=="U" && $15 == "U" && $5 > 30 && $12 > 30 && (($2==$9 && $10-$3 < T && $4==$11) || ($2==$9 && $10-$3 >= T) || $2!=$9){
	TOTAL_READ++;
	print > f
}END{
	print TOTAL_READ
}' > ${DIR_tmp}/total_read.txt


### sampling map
awk -v OFS='\t' -v n=$(cat ${DIR_tmp}/total_read.txt) -v p=$T_NUMBER 'BEGIN{
	srand();
}rand() * n-- < p{
	p--;
	print;
}' < ${DIR_tmp}/map.txt >> ${DIR_tmp}/sampled_map.txt

gzip ${DIR_tmp}/sampled_map.txt
mv ${DIR_tmp}/sampled_map.txt.gz $FILE_out

exit 0
