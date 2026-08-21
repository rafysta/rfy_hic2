#!/bin/bash
# Check that the Rscript found in PATH can load the R packages this stage needs.
#
# Usage : bash check_R_packages.sh optparse data.table RSQLite
#
# Exits with 1 and an explanatory message if Rscript is missing or a package
# cannot be loaded. This catches the common cluster problem of a "module load R"
# selecting an R installation that does not see the user library, which would
# otherwise make later steps produce empty or truncated output files.

if ! command -v Rscript >/dev/null 2>&1; then
	echo "Rscript is not available. Please install R or add it to PATH." >&2
	exit 1
fi

RFY_CHECK_PKGS="$@"
export RFY_CHECK_PKGS
RESULT=$(Rscript --vanilla --no-echo -e '
pkgs <- strsplit(trimws(Sys.getenv("RFY_CHECK_PKGS")), "[ ,]+")[[1]]
pkgs <- pkgs[nzchar(pkgs)]
miss <- pkgs[!sapply(pkgs, function(p) suppressWarnings(requireNamespace(p, quietly=TRUE)))]
cat("RFY_CHECK_DONE", paste(miss, collapse=" "))
' 2>/dev/null)

# the sentinel confirms that Rscript itself ran to the end
case "${RESULT}" in
	RFY_CHECK_DONE*) MISSING=$(echo "${RESULT#RFY_CHECK_DONE}" | xargs) ;;
	*)
		echo "Rscript did not run correctly: $(command -v Rscript)" >&2
		echo "Check the R installation in PATH." >&2
		exit 1
		;;
esac

if [ -n "${MISSING}" ]; then
	cat >&2 <<-EOF
	R package(s) not available: ${MISSING}
	  Rscript in use : $(command -v Rscript)
	  R library paths: $(Rscript --vanilla --no-echo -e 'cat(paste(.libPaths(), collapse=", "))' 2>/dev/null)
	Install the package(s), or make sure the intended R is in PATH.
	On a cluster, a "module load R" may hide the user library that holds these packages.
	EOF
	exit 1
fi
exit 0
