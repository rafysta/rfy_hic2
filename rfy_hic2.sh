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

	--env_check
		check environment is correctly setting

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

do_envcheck(){
	command -v bowtie2 >/dev/null 2>&1 || echo "bowtie2 command is not available. Please install it or pathを通してください。"
	command -v samtools >/dev/null 2>&1 || echo "samtools command is not available. Please install it or pathを通してください。"
	command -v Rscript >/dev/null 2>&1 || echo "R is not available. Please install it or pathを通してください。"
	command -v gzip >/dev/null 2>&1 || echo "gzip is not available. Please install it or pathを通してください。"
	command -v sqlite3 >/dev/null 2>&1 || echo "sqlite3 is not available. Please install it or pathを通してください。"
	command -v fastqc >/dev/null 2>&1 || echo "fastqc is not available. もしQCを行う場合は、install it or pathを通してください。"
}

SHORT=hv
LONG=help,version,env_check,arg:,stages:
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
		--env_check)
			do_envcheck
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
	echo "Start step1 ..."
	sh ${DIR_LIB}/1_configure_index_file.sh --arg $FILE_ARG
	echo "Finished step1"
fi

if [[ "${RUN_STAGES}" == *"2"* ]]; then
	echo "Start step2 ..."
	sh ${DIR_LIB}/2_make_map_file.sh --arg $FILE_ARG
	echo "Finished step2"
fi

if [[ "${RUN_STAGES}" == *"3"* ]]; then
	echo "Start step3 ..."
	sh ${DIR_LIB}/3_make_fragment_db.sh --arg $FILE_ARG
	echo "Finished step3"
fi

if [[ "${RUN_STAGES}" == *"4"* ]]; then
	echo "Start step4 ..."
	sh ${DIR_LIB}/4_read_filtering_summary.sh --arg $FILE_ARG ${NAME}
	echo "Finished step4"
fi

if [[ "${RUN_STAGES}" == *"5"* ]]; then
	echo "Start step5 ..."
	for RESOLUTION in ${RESOLUTIONs}
	do
		sh ${DIR_LIB}/5_matrix_generation.sh --arg $FILE_ARG --resolution ${RESOLUTION}
	done
	echo "Finished step5"
fi
