#!/bin/bash
# Remove the output of a sample from a given stage onwards, so that the stage
# can be re-run from a clean state.
#
# Files written before the given stage are kept. In particular stage 2
# (alignment, the expensive step) is never touched unless --stage 2 is given.
#
# By default nothing is deleted: the files that would be removed are listed.
# Add --yes to actually delete them.

get_usage(){
	cat <<-EOF

Usage : $0 -d [data directory] -n [sample name] --stage [2|3|5|6] [--yes]

Description
	-h, --help
		show help

	--arg [setting file]
		parameter setting file (DIR_DATA and NAME can come from here)

	-d, --directory [data directory]
		data directory (DIR_DATA)

	-n, --name [sample name]
		sample name (NAME)

	--stage [2|3|5|6]
		remove the output of this stage and of all later stages.
		  2 : alignment (NAME.map.gz, NAME.db, sam files) and everything after
		  3 : fragment database, distance curve, bad fragment list, matrices, .hic
		  5 : matrices (NAME/<RES>/) and .hic
		  6 : .hic file only
		default: 3

	--yes
		actually delete. Without this option the files are only listed.
	EOF
}

SHORT=hd:n:
LONG=help,arg:,directory:,name:,stage:,yes
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
		--stage)
			STAGE="$2"
			shift 2
			;;
		--yes)
			FLAG_YES="TRUE"
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

DIR_LIB=$(dirname $0)/..
source ${DIR_LIB}/utils/load_argfile.sh DIR_DATA NAME

[ ! -n "${NAME:-}" ] && echo "Please specify NAME" && exit 1
[ ! -n "${DIR_DATA:-}" ] && echo "Please specify data directory" && exit 1
STAGE=${STAGE:-3}
FLAG_YES=${FLAG_YES:-FALSE}

TARGETS=""
add(){ for f in "$@"; do [ -e "$f" ] && TARGETS="${TARGETS} $f"; done; }

# stage 6
add ${DIR_DATA}/${NAME}/${NAME}.hic ${DIR_DATA}/${NAME}/${NAME}.short.gz

# stage 5
if [ ${STAGE} -le 5 ]; then
	for d in ${DIR_DATA}/${NAME}/*/; do
		[ -e "${d}" ] || continue
		case $(basename ${d}) in
			*b|*bp|*f) add ${d%/} ;;
		esac
	done
fi

# stage 3
if [ ${STAGE} -le 3 ]; then
	add ${DIR_DATA}/${NAME}_fragment.db ${DIR_DATA}/${NAME}_fragment_pair.txt ${DIR_DATA}/${NAME}_fragment_pair.txt.gz \
		${DIR_DATA}/${NAME}_fragment.txt ${DIR_DATA}/${NAME}_fragment.png ${DIR_DATA}/${NAME}_bad_fragment.txt \
		${DIR_DATA}/${NAME}_distance.txt ${DIR_DATA}/${NAME}_distance_accurate.txt \
		${DIR_DATA}/${NAME}_InterChromosome.matrix
fi

# stage 2
if [ ${STAGE} -le 2 ]; then
	add ${DIR_DATA}/${NAME}.map ${DIR_DATA}/${NAME}.map.gz ${DIR_DATA}/${NAME}.db \
		${DIR_DATA}/${NAME}_DNA_amount.bed ${DIR_DATA}/${NAME}_alignment.log \
		${DIR_DATA}/${NAME}_read_filtering.log ${DIR_DATA}/${NAME}_alignment_summary.txt \
		${DIR_DATA}/${NAME}_1.sam ${DIR_DATA}/${NAME}_2.sam \
		${DIR_DATA}/${NAME}_1_bowtie2.log ${DIR_DATA}/${NAME}_2_bowtie2.log
fi

if [ ! -n "${TARGETS}" ]; then
	echo "Nothing to remove for ${NAME} (stage ${STAGE} and later)"
	exit 0
fi

echo "Sample ${NAME}: output of stage ${STAGE} and later"
for f in ${TARGETS}; do
	printf "  %-70s %s\n" "${f}" "$(du -sh ${f} 2>/dev/null | cut -f1)"
done

if [ "${FLAG_YES}" = "TRUE" ]; then
	rm -rf ${TARGETS}
	echo "removed."
else
	echo ""
	echo "Nothing was deleted. Add --yes to remove these files."
fi
