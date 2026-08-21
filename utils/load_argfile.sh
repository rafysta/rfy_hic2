#!/bin/bash
# Load parameter setting file (argfile) while keeping command-line options.
#
# Usage (from a stage script, after option parsing):
#   source ${DIR_LIB}/utils/load_argfile.sh VAR1 VAR2 ...
#
# VAR1 VAR2 ... are the variable names that can be set from the command line.
# Values already set by command-line options take precedence over the values
# in the argfile, so that e.g.
#   bash 5_matrix_generation.sh --arg project.env --resolution 5kb
# uses RESOLUTION from the command line even if the argfile defines it.
#
# The argfile is a plain bash file and is sourced, so it may contain
# "module load ..." lines or "source other.env" lines.

if [ -n "${FILE_ARG:-}" ]; then
	if [ ! -e "${FILE_ARG}" ]; then
		echo "Parameter setting file not found: ${FILE_ARG}" >&2
		exit 1
	fi
	__CLI_SAVED=""
	for __v in "$@"; do
		if [ -n "${!__v:-}" ]; then
			__CLI_SAVED="${__CLI_SAVED}$(declare -p ${__v});"
		fi
	done
	set -a
	source "${FILE_ARG}"
	set +a
	eval "${__CLI_SAVED}"
	unset __CLI_SAVED __v
fi
