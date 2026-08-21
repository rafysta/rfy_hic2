#!/bin/bash
# Make a multi-resolution Juicer .hic file (NONE / ICE / KR in one file)
#
# NONE : identical to the rfy_hic2 raw matrices (<RES>/Raw/ALL.rds) at every
#        resolution. The fragment database is converted to Juicer "short with
#        score" records *before* binning so that "juicer_tools pre" reproduces
#        the same bin assignment (see utils/Make_juicer_short_from_fragmentdb.pl).
# ICE  : the ICE2 bias vectors (<RES>/ICE2/*_bias.txt) are added with
#        "juicer_tools addNorm". Identical to <RES>/ICE2/ALL.rds.
# KR   : (or other Juicer normalization) calculated by juicer_tools on the
#        same raw counts.

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

	-d, --directory [data directory]
		data directory (DIR_DATA)

	-n, --name [sample name]
		sample name (NAME)

	-o, --out [output .hic file]
		default: DIR_DATA/NAME/NAME.hic

	-r, --resolution [resolution list]
		comma separated. e.g. 1kb,2kb,5kb,10kb,20kb,100kb or 1000,2000,...
		default: RESOLUTIONs_hic in argfile, or RESOLUTIONs (space separated)

	--norm [juicer normalization list]
		comma separated normalizations calculated by juicer_tools pre.
		e.g. KR or KR,VC. NONE to skip. default: KR

	--ice [TRUE/FALSE]
		add ICE2 bias vectors as normalization "ICE". default: TRUE
		Bias files (<RES>/ICE2/ALL_bias.txt or <CHR>_bias.txt) are used.
		If they do not exist but ICE2 matrices exist, the bias is re-calculated
		from <RES>/Raw/ALL.rds with the same parameters and saved.

	--ice_name [name]
		name of the ICE normalization in the .hic file. default: ICE

	--ice_threshold [default: 0.02]
		threshold for ICE normalization (used only when bias is re-calculated)

	--juicer [juicer_tools.jar]
		path of juicer_tools jar file (PROGRAM_JUICER)

	--java_mem [e.g. 100g]
		Java heap size (JAVA_MEM). default: 100g

	-j, --threads [number]
		threads for juicer_tools. default: 1

	--include [chromosome list]
		comma separated list of chromosomes to include

	--exclude [chromosome list]
		comma separated list of chromosomes to exclude

	-t, --threshold [self ligation threshold. default: 10000]
		same as 5_matrix_generation.sh (THRESHOLD_SELF)

	--use_blacklist [TRUE/FALSE]
		use fragment blacklist. default: TRUE

	--tmp [temporary directory]
		default: DIR_tmporary in argfile or /tmp

	--keep_short [TRUE/FALSE]
		keep the intermediate short format file next to the .hic file. default: FALSE
	EOF
}

get_version(){
	echo "${0} version 2.0"
}

SHORT=hvd:n:o:r:j:t:
LONG=help,version,arg:,directory:,name:,out:,resolution:,norm:,ice:,ice_name:,ice_threshold:,juicer:,java_mem:,threads:,include:,exclude:,threshold:,use_blacklist:,tmp:,keep_short:
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
		-o|--out)
			FILE_HIC="$2"
			shift 2
			;;
		-r|--resolution)
			RESOLUTIONs_hic="$2"
			shift 2
			;;
		--norm)
			HIC_NORM="$2"
			shift 2
			;;
		--ice)
			FLAG_ICE="$2"
			shift 2
			;;
		--ice_name)
			ICE_NAME="$2"
			shift 2
			;;
		--ice_threshold)
			THRESHOLD_ICE="$2"
			shift 2
			;;
		--juicer)
			PROGRAM_JUICER="$2"
			shift 2
			;;
		--java_mem)
			JAVA_MEM="$2"
			shift 2
			;;
		-j|--threads)
			THREADS="$2"
			shift 2
			;;
		--include)
			CHR_include="$2"
			shift 2
			;;
		--exclude)
			CHR_exclude="$2"
			shift 2
			;;
		-t|--threshold)
			THRESHOLD_SELF="$2"
			shift 2
			;;
		--use_blacklist)
			FLAG_blacklist="$2"
			shift 2
			;;
		--tmp)
			DIR_tmporary="$2"
			shift 2
			;;
		--keep_short)
			FLAG_keep_short="$2"
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

#-----------------------------------------------
# Load setting
#-----------------------------------------------
source ${DIR_LIB}/utils/load_argfile.sh DIR_DATA NAME FILE_HIC RESOLUTIONs_hic HIC_NORM FLAG_ICE ICE_NAME THRESHOLD_ICE PROGRAM_JUICER JAVA_MEM THREADS CHR_include CHR_exclude THRESHOLD_SELF FLAG_blacklist DIR_tmporary FLAG_keep_short

# fail early if the R in PATH cannot load the packages used by this stage
bash ${DIR_LIB}/utils/check_R_packages.sh optparse data.table || exit 1

[ ! -n "${NAME:-}" ] && echo "Please specify NAME" && exit 1
[ ! -n "${DIR_DATA:-}" ] && echo "Please specify data directory" && exit 1
[ ! -n "${FILE_CHROME_LENGTH:-}" ] && echo "Please specify FILE_CHROME_LENGTH (chromosome length file)" && exit 1
[ ! -n "${PROGRAM_JUICER:-}" ] && echo "Please specify juicer_tools jar file (PROGRAM_JUICER or --juicer)" && exit 1
[ ! -e "${PROGRAM_JUICER}" ] && echo "juicer_tools jar not found: ${PROGRAM_JUICER}" && exit 1
command -v java >/dev/null 2>&1 || { echo "java is not available. Please install it or load the module"; exit 1; }

FILE_HIC=${FILE_HIC:-"${DIR_DATA}/${NAME}/${NAME}.hic"}
HIC_NORM=${HIC_NORM:-KR}
FLAG_ICE=${FLAG_ICE:-TRUE}
ICE_NAME=${ICE_NAME:-ICE}
THRESHOLD_ICE=${THRESHOLD_ICE:-0.02}
JAVA_MEM=${JAVA_MEM:-100g}
THREADS=${THREADS:-1}
CHR_include=${CHR_include:-NA}
CHR_exclude=${CHR_exclude:-NA}
THRESHOLD_SELF=${THRESHOLD_SELF:-10000}
FLAG_blacklist=${FLAG_blacklist:-TRUE}
DIR_tmporary=${DIR_tmporary:-/tmp}
FLAG_keep_short=${FLAG_keep_short:-FALSE}

# resolution list: default from RESOLUTIONs (space separated, kb notation)
if [ ! -n "${RESOLUTIONs_hic:-}" ]; then
	[ ! -n "${RESOLUTIONs:-}" ] && echo "Please specify resolutions (--resolution or RESOLUTIONs_hic / RESOLUTIONs in argfile)" && exit 1
	RESOLUTIONs_hic=$(echo ${RESOLUTIONs} | tr ' ' ',')
fi
RESOLUTIONs_hic=$(echo ${RESOLUTIONs_hic} | tr ' ' ',')
# convert 20kb -> 20000 etc.
RESOLUTION_BP_LIST=""
RESOLUTION_STRING_LIST=""
for R in $(echo ${RESOLUTIONs_hic} | tr ',' ' '); do
	BP=${R/Mb/000000}; BP=${BP/kb/000}; BP=${BP/bp/}
	RESOLUTION_BP_LIST="${RESOLUTION_BP_LIST},${BP}"
	RESOLUTION_STRING_LIST="${RESOLUTION_STRING_LIST} ${R}"
done
RESOLUTION_BP_LIST=${RESOLUTION_BP_LIST#,}

[ ! -e ${DIR_DATA}/${NAME}_fragment.db ] && echo "fragment database not found: ${DIR_DATA}/${NAME}_fragment.db" && exit 1
[ "$FLAG_blacklist" = "TRUE" ] && [ ! -e ${DIR_DATA}/${NAME}_bad_fragment.txt ] && echo "bad fragment list not exists" && exit 1
[ ! -e $(dirname ${FILE_HIC}) ] && mkdir -p $(dirname ${FILE_HIC})

#-----------------------------------------------
# Temporary directory
#-----------------------------------------------
[ ! -e ${DIR_tmporary} ] && mkdir -p ${DIR_tmporary}
DIR_tmp=$(mktemp -d ${DIR_tmporary}/tmp_rfy_hic2_juicer.XXXXXX)
trap "rm -rf ${DIR_tmp}" 0

#-----------------------------------------------
# Load chromosome length
#-----------------------------------------------

CHR_TABLE=$(Rscript --vanilla --no-echo ${DIR_LIB}/utils/Chromosome_length.R --in $FILE_CHROME_LENGTH --include $CHR_include --exclude $CHR_exclude) || { echo "Chromosome_length.R failed"; exit 1; }
CHRs=($(echo $CHR_TABLE | xargs -n1 | awk 'NR==1' | tr ',' ' '))
LENGTH=($(echo $CHR_TABLE | xargs -n1 | awk 'NR==2' | tr ',' ' '))
CHRs_list=$(echo ${CHRs[@]} | tr ' ' ',')
[ ${#CHRs[@]} -eq 0 ] && echo "No chromosome was obtained from ${FILE_CHROME_LENGTH}" && exit 1

FILE_CHROM_SIZES=${DIR_tmp}/chrom.sizes
for i in $(seq 1 ${#CHRs[@]}); do
	let index=i-1
	echo -e "${CHRs[index]}\t${LENGTH[index]}"
done > ${FILE_CHROM_SIZES}

echo "[$(date)] $NAME : chromosomes = ${CHRs_list}, resolutions = ${RESOLUTION_BP_LIST}"

#==============================================================
# 1. fragment db -> juicer short with score format
#==============================================================
FILE_SHORT=${DIR_tmp}/${NAME}.short.gz
if [ "$FLAG_blacklist" = "TRUE" ]; then
	perl ${DIR_LIB}/utils/Make_juicer_short_from_fragmentdb.pl -i ${DIR_DATA}/${NAME}_fragment.db -o ${FILE_SHORT} -c ${CHRs_list} -t ${THRESHOLD_SELF} -b ${DIR_DATA}/${NAME}_bad_fragment.txt
else
	perl ${DIR_LIB}/utils/Make_juicer_short_from_fragmentdb.pl -i ${DIR_DATA}/${NAME}_fragment.db -o ${FILE_SHORT} -c ${CHRs_list} -t ${THRESHOLD_SELF}
fi
[ $? -ne 0 ] && echo "conversion to short format failed" && exit 1
N_RECORD=$(zcat ${FILE_SHORT} | head -n 1 | wc -l)
[ "${N_RECORD}" -eq 0 ] && echo "no record was written to the short format file (empty fragment db, wrong chromosome names, or all fragments blacklisted)" && exit 1
echo "[$(date)] $NAME : short format created"

#==============================================================
# 2. juicer pre (NONE + juicer normalizations)
#==============================================================
COMMAND="java -Xmx${JAVA_MEM} -jar ${PROGRAM_JUICER} pre -r ${RESOLUTION_BP_LIST} -t ${DIR_tmp} -j ${THREADS}"
if [ "${HIC_NORM}" = "NONE" ] || [ ! -n "${HIC_NORM}" ]; then
	COMMAND="${COMMAND} -n"
else
	COMMAND="${COMMAND} -k ${HIC_NORM}"
fi
FILE_HIC_tmp=${DIR_tmp}/${NAME}.hic
COMMAND="${COMMAND} ${FILE_SHORT} ${FILE_HIC_tmp} ${FILE_CHROM_SIZES}"
echo ${COMMAND}
eval ${COMMAND}
STATUS=$?
[ ${STATUS} -ne 0 ] && echo "juicer pre failed (exit ${STATUS})" && exit 1
[ ! -s ${FILE_HIC_tmp} ] && echo "juicer pre failed (no output)" && exit 1
java -Xmx${JAVA_MEM} -jar ${PROGRAM_JUICER} validate ${FILE_HIC_tmp} >/dev/null 2>&1 || { echo "juicer pre produced an invalid .hic file"; exit 1; }
echo "[$(date)] $NAME : juicer pre finished"

#==============================================================
# 3. ICE bias vectors -> addNorm
#==============================================================
if [ "$FLAG_ICE" = "TRUE" ]; then
	FILE_VECTOR=${DIR_tmp}/${NAME}_${ICE_NAME}_vectors.txt
	rm -f ${FILE_VECTOR}
	N_ADDED=0
	for RES in ${RESOLUTION_STRING_LIST}; do
		BP=${RES/Mb/000000}; BP=${BP/kb/000}; BP=${BP/bp/}
		DIR_RES=${DIR_DATA}/${NAME}/${RES}
		if [ ! -e ${DIR_RES}/ICE2 ]; then
			echo "  ${RES}: ICE2 directory not found. ${ICE_NAME} is not added for this resolution."
			continue
		fi

		# ---- collect bias files (re-calculate if missing) ----
		BIAS_FILES=""
		if [ -e ${DIR_RES}/ICE2/ALL.rds ] || [ -e ${DIR_RES}/ICE2/ALL.matrix ] || [ -e ${DIR_RES}/ICE2/ALL.matrix.gz ]; then
			# genome-wide mode (FLAG_INTRA=FALSE)
			if [ ! -e ${DIR_RES}/ICE2/ALL_bias.txt ]; then
				if [ ! -e ${DIR_RES}/Raw/ALL.rds ]; then
					echo "  ${RES}: Raw/ALL.rds not found. cannot re-calculate bias. skipped."
					continue
				fi
				echo "  ${RES}: re-calculating ICE2 bias from Raw/ALL.rds"
				mkdir -p ${DIR_tmp}/ice_${RES}
				Rscript --vanilla --no-echo ${DIR_LIB}/utils/Bias_normalization_ICE2.R -i ${DIR_RES}/Raw/ALL.matrix -o ${DIR_tmp}/ice_${RES}/ALL.matrix --log ${DIR_tmp}/ice_${RES}/ALL.log --times 30 --threshold ${THRESHOLD_ICE} --bias_out ${DIR_RES}/ICE2/ALL_bias.txt || { echo "ICE2 bias re-calculation failed for ${RES}"; exit 1; }
			fi
			BIAS_FILES=${DIR_RES}/ICE2/ALL_bias.txt
		else
			# per chromosome mode (FLAG_INTRA=TRUE)
			for CHR in ${CHRs[@]}; do
				if [ ! -e ${DIR_RES}/ICE2/${CHR}_bias.txt ]; then
					if [ ! -e ${DIR_RES}/Raw/${CHR}.rds ]; then
						echo "  ${RES}: Raw/${CHR}.rds not found. skipped."
						continue
					fi
					echo "  ${RES}: re-calculating ICE2 bias for ${CHR}"
					mkdir -p ${DIR_tmp}/ice_${RES}
					INTER_OPT=""
					[ -e ${DIR_RES}/InterBin/${CHR}.txt ] && INTER_OPT="--inter ${DIR_RES}/InterBin/${CHR}.txt"
					Rscript --vanilla --no-echo ${DIR_LIB}/utils/Bias_normalization_ICE2.R -i ${DIR_RES}/Raw/${CHR}.matrix -o ${DIR_tmp}/ice_${RES}/${CHR}.matrix --log ${DIR_tmp}/ice_${RES}/${CHR}.log ${INTER_OPT} --times 30 --threshold ${THRESHOLD_ICE} --bias_out ${DIR_RES}/ICE2/${CHR}_bias.txt || { echo "ICE2 bias re-calculation failed for ${RES} ${CHR}"; exit 1; }
				fi
				[ -e ${DIR_RES}/ICE2/${CHR}_bias.txt ] && BIAS_FILES="${BIAS_FILES},${DIR_RES}/ICE2/${CHR}_bias.txt"
			done
			BIAS_FILES=${BIAS_FILES#,}
		fi
		[ ! -n "${BIAS_FILES}" ] && continue

		Rscript --vanilla --no-echo ${DIR_LIB}/utils/Make_norm_vector.R -i ${BIAS_FILES} -o ${FILE_VECTOR} -l ${FILE_CHROM_SIZES} -r ${BP} -n ${ICE_NAME} -c ${CHRs_list} || { echo "Make_norm_vector.R failed for ${RES}"; exit 1; }
		let N_ADDED=N_ADDED+1
		echo "  ${RES}: ${ICE_NAME} vector prepared"
	done

	if [ ${N_ADDED} -gt 0 ]; then
		java -Xmx${JAVA_MEM} -jar ${PROGRAM_JUICER} addNorm -j ${THREADS} ${FILE_HIC_tmp} ${FILE_VECTOR} || { echo "juicer addNorm failed"; exit 1; }
		echo "[$(date)] $NAME : ${ICE_NAME} normalization added for ${N_ADDED} resolution(s)"
	else
		echo "[$(date)] $NAME : no ICE bias available. ${ICE_NAME} normalization was not added"
	fi
fi

#==============================================================
# 4. move to output
#==============================================================
mv ${FILE_HIC_tmp} ${FILE_HIC}
[ "$FLAG_keep_short" = "TRUE" ] && mv ${FILE_SHORT} $(dirname ${FILE_HIC})/${NAME}.short.gz
echo "[$(date)] $NAME : ${FILE_HIC} created"
exit 0
