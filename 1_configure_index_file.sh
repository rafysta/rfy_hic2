#!/bin/bash
# make index file for restriction sites

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

	-i, --fasta [genome's fasta file]
		genome's fasta sequence file

	-t, --restriction [nucleotide sequence of restriction site(s). For multiple restrictions, separated by , ex: GATC,GAATC,GATTC,GAGTC,GACTC]
		制限酵素部位の認識配列

	--out_site [制限酵素の切断部位のリストファイルの出力ファイル名]
		制限酵素の切断部位のリストファイルの出力ファイル名
	
	--out_site_index [制限酵素の切断部位をsearchするためのハッシュファイル]
		制限酵素の切断部位をsearchするためのハッシュファイル
	EOF

}

get_version(){
	cat <<-EOF
	${0} version 2.0
	EOF
}

SHORT=hvi:t:
LONG=help,version,arg:,fasta:,restriction:,out_site:,out_site_index:
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
		-i|--fasta)
			FILE_fasta="$2"
			shift 2
			;;
		-t|--restriction)
			RECOGNITION_SITES="$2"
			shift 2
			;;
		--out_site)
			FILE_enzyme_def="$2"
			shift 2
			;;
		--out_site_index)
			FILE_enzyme_index="$2"
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

#-----------------------------------------------
# Load setting
#-----------------------------------------------
[ ! -n "${FILE_ARG}" ] && source ${FILE_ARG}

[ ! -n "${FILE_fasta}" ] && echo "Please specify input genome fasta file" && exit 1
[ ! -n "${RECOGNITION_SITES}" ] && echo "Please specify recognition sequences" && exit 1
[ ! -n "${FILE_enzyme_def}" ] && echo "Please specify restriction site file" && exit 1
[ ! -n "${FILE_enzyme_index}" ] && echo "Please specify restriction site index file" && exit 1

DIR_LIB=$(dirname $0)


#-----------------------------------------------
# divide reference sequence by restriction enzyme sites
#-----------------------------------------------
perl ${DIR_LIB}/utils/Divide-sequence_by_enzymeSequence.pl -i ${FILE_fasta} -t ${RECOGNITION_SITES} > ${FILE_enzyme_def}


#-----------------------------------------------
# make index file
#-----------------------------------------------
perl ${DIR_LIB}/utils/Sectioning_enzymeSites.pl -i ${FILE_enzyme_def} > ${FILE_enzyme_index}


