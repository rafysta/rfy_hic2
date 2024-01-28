#!/bin/bash
# Distance curve calculation

get_usage(){
	cat <<EOF

Usage : $0 [OPTION]

Description
	-h, --help
		show help

	-v, --version
		show version

	-i, --in [map file (xxx.map.gz)]
		map file

	-o, --out [output file]
		output file name
EOF

}

get_version(){
	echo "${0} version 1.0"
}

SHORT=hvi:o:
LONG=help,version,in:out:
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
		-i|--in)
			FILE_map="$2"
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

[ ! -n "${FILE_map}" ] && echo "Please specify map file" && exit 1
[ ! -n "${FILE_out}" ] && echo "Please specify output file name" && exit 1
PARAM=${PARAM:-10}


zcat ${FILE_map} | awk -v OFS='\t' '$8=="U" && $15=="U" && $2 == $9 && ($10-$3) < 2000000{
	distance=int(($10-$3)/10)*10;
	combination=$4$11;
	count[distance"\t"combination]++;
}END{
	for(x in count){
		print x,count[x]
	}
}' > ${FILE_out}

