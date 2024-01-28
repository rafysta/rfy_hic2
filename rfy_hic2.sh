#!/bin/bash -eu
# Hi-C processing pipeline

get_usage(){
	cat <<-EOF

Usage : $0 [OPTION]

Description
	-h, --help
		show help

	-v, --version
		show version

	--arg [setting file]
		parameter setting file

	--stages [default: 2345]
		run stages
	EOF

}

get_version(){
	cat <<-EOF
	${0} version 2.0
	EOF
}

SHORT=hv
LONG=help,version,arg:,stages:
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
		--stages)
			RUN_STAGES="$2"
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

[ ! -n "${FILE_ARG}" ] && echo "Please specify parameter setting file" && exit 1
RUN_STAGES=${RUN_STAGES:-2345}

#-----------------------------------------------
# Load setting file
#-----------------------------------------------
source $FILE_ARG

#-----------------------------------------------
# Run steps
#-----------------------------------------------
if [[ "${RUN_STAGES}" == *"1"* ]]; then
	sh ${DIR_LIB}/1_configure_index_file.sh --arg $FILE_ARG
fi

if [[ "${RUN_STAGES}" == *"2"* ]]; then
	sh ${DIR_LIB}/2_make_map_file.sh --arg $FILE_ARG
fi

if [[ "${RUN_STAGES}" == *"3"* ]]; then
	sh ${DIR_LIB}/3_make_fragment_db.sh --arg $FILE_ARG
fi

if [[ "${RUN_STAGES}" == *"4"* ]]; then
	sh ${DIR_LIB}/4_read_filtering_summary.sh --arg $FILE_ARG ${NAME}
fi

if [[ "${RUN_STAGES}" == *"5"* ]]; then
	for RESOLUTION in "${RESOLUTIONs}"
	do
		sh ${DIR_LIB}/5_matrix_generation.sh --arg $FILE_ARG --resolution ${RESOLUTION}
	done
fi