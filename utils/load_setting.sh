#!/bin/bash
# Loading setting

get_usage(){
	cat <<EOF

Usage : $0 [OPTION]

Description
	-h, --help
		show help

	-v, --version
		show version

	-x, --ref [reference seq]
		reference seq name

	-r, --restriction [restriction enzyme]
		restriction enzyme
EOF

}

get_version(){
	echo "${0} version 1.0"
}

SHORT=hvx:r:
LONG=help,version,ref:,restriction:
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
		-x|--ref)
			REF="$2"
			shift 2
			;;
		-r|--restriction)
			RESTRICTION="$2"
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

[ ! -n "${REF}" ] && echo "Please specify reference" && exit 1
[ ! -n "${RESTRICTION}" ] && echo "Please specify restriction" && exit 1
[ ! -n "${GENOME_DIR}" ] && echo "Please specify genome reference directory" && exit 1

case $REF in
	pombe)	BOWTIE2_INDEX=${GENOME_DIR}/pombe/2018/Bowtie2/pombe
			CHROM_LENGTH=12571820
			FILE_CHROME_LENGTH=${GENOME_DIR}/pombe/2018/LENGTH.txt
			case $RESTRICTION in 
				MboI)	FILE_enzyme_index=${GENOME_DIR}/pombe/2018/Sectioning_MboI.txt
						FILE_enzyme_def=${GENOME_DIR}/pombe/2018/MboI_sites.txt ;;
				MboI-Hinf1)	FILE_enzyme_index=${GENOME_DIR}/pombe/2018/Sectioning_MboI-Hinf1.txt
						FILE_enzyme_def=${GENOME_DIR}/pombe/2018/MboI-Hinf1_sites.txt ;;
				MboI-Hinf1-MluCl)	FILE_enzyme_index=${GENOME_DIR}/pombe/2018/Sectioning_MboI-Hinf1-MluCl.txt
						FILE_enzyme_def=${GENOME_DIR}/pombe/2018/MboI-Hinf1-MluCl_sites.txt ;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	OR74A)	BOWTIE2_INDEX=${GENOME_DIR}/neurospora_crassa/OR74A/Bowtie2/or74a
			CHROM_LENGTH=40463072
			FILE_CHROME_LENGTH=${GENOME_DIR}/neurospora_crassa/OR74A/LENGTH_mainChromosome.txt
			case $RESTRICTION in 
				DpnII)	FILE_enzyme_index=${GENOME_DIR}/neurospora_crassa/OR74A/Sectioning_DpnII.txt
						FILE_enzyme_def=${GENOME_DIR}/neurospora_crassa/OR74A/DpnII_sites.txt ;;
				HindIII)	FILE_enzyme_index=${GENOME_DIR}/neurospora_crassa/OR74A/Sectioning_HindIII.txt
						FILE_enzyme_def=${GENOME_DIR}/neurospora_crassa/OR74A/HindIII_sites.txt ;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	ASM329048v1)	BOWTIE2_INDEX=${GENOME_DIR}/malassezia/ASM329048v1/Bowtie2/ASM329048v1
			CHROM_LENGTH=7369627
			FILE_CHROME_LENGTH=${GENOME_DIR}/malassezia/ASM329048v1/LENGTH.txt
			case $RESTRICTION in 
				MboI)	FILE_enzyme_index=${GENOME_DIR}/malassezia/ASM329048v1/Sectioning_MboI.txt
						FILE_enzyme_def=${GENOME_DIR}/malassezia/ASM329048v1/MboI_sites.txt ;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	hg19)	BOWTIE2_INDEX=${GENOME_DIR}/human/hg19/Bowtie2/hg19
			CHROM_LENGTH=3095677412
			FILE_CHROME_LENGTH=${GENOME_DIR}/human/hg19/LENGTH.txt
			case $RESTRICTION in 
				HindIII)	FILE_enzyme_index=${GENOME_DIR}/human/hg19/Sectioning_HindIII.txt
							FILE_enzyme_def=${GENOME_DIR}/human/hg19/HindIII_sites.txt ;;
				MboI)	FILE_enzyme_index=${GENOME_DIR}/human/hg19/Sectioning_MboI.txt
						FILE_enzyme_def=${GENOME_DIR}/human/hg19/MboI_sites.txt ;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	KC207813.1_hg19)	BOWTIE2_INDEX=${GENOME_DIR}/ebv/KC207813.1_hg19/Bowtie2/EBV
			CHROM_LENGTH=3095865306
			FILE_CHROME_LENGTH=${GENOME_DIR}/ebv/KC207813.1_hg19/LENGTH.txt
			case $RESTRICTION in 
				MboI)	FILE_enzyme_index=${GENOME_DIR}/ebv/KC207813.1_hg19/Sectioning_MboI.txt
						FILE_enzyme_def=${GENOME_DIR}/ebv/KC207813.1_hg19/MboI_sites.txt;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	V01555.2_hg19)	BOWTIE2_INDEX=${GENOME_DIR}/ebv/V01555.2_hg19/Bowtie2/EBV
			CHROM_LENGTH=3095866264
			FILE_CHROME_LENGTH=${GENOME_DIR}/ebv/V01555.2_hg19/LENGTH.txt
			case $RESTRICTION in 
				MboI)	FILE_enzyme_index=${GENOME_DIR}/ebv/V01555.2_hg19/Sectioning_MboI.txt
						FILE_enzyme_def=${GENOME_DIR}/ebv/V01555.2_hg19/MboI_sites.txt;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	mm10)	BOWTIE2_INDEX=${GENOME_DIR}/mouse/mm10/Bowtie2/mm10
			CHROM_LENGTH=2725537669
			FILE_CHROME_LENGTH=${GENOME_DIR}/mouse/mm10/LENGTH.txt
			case $RESTRICTION in 
				MboI)	FILE_enzyme_index=${GENOME_DIR}/mouse/mm10/Sectioning_MboI.txt
						FILE_enzyme_def=${GENOME_DIR}/mouse/mm10/MboI_sites.txt ;;
				NA) ;;
				*)	echo "$RESTRICTION is not registered for $ORGANISM"
					exit ;;
			esac
			;;
	*)	echo "Please specify correct reference name"
		exit 1 ;;
esac
