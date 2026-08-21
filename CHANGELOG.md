# Changelog

## 2.1 (2026-08)

### Added
- `6_make_hic_file.sh`: one multi-resolution `.hic` file per sample with
  `NONE` (= `Raw/ALL.rds`), `ICE` (= `ICE2/ALL.rds`, added with
  `juicer_tools addNorm`) and `KR`. Stage 6 of `rfy_hic2.sh` (`--stages 23456`).
- `utils/Make_juicer_short_from_fragmentdb.pl`: fragment database -> Juicer
  short-with-score records, written before binning so that `pre` reproduces
  the stage-5 bin assignment at every resolution.
- `utils/Make_norm_vector.R`: bias vectors -> `addNorm` input.
- `utils/Verify_hic_file.R`: compares `.hic` content with the rds matrices.
- `utils/Bias_normalization_ICE2.R --bias_out`: writes the bias vector
  (`<RES>/ICE2/ALL_bias.txt`, `<CHR>_bias.txt`). `Raw / (bias_i * bias_j)`
  equals the ICE2 matrix.
- `5_matrix_generation.sh --ice_threshold` (default 0.02, unchanged behaviour).
- `utils/Distance_curve_accurate.pl` (from rfy_hic): distance curve from the
  fragment database; written by stage 3 as `NAME_distance_accurate.txt`.
- `utils/load_argfile.sh`: argfile loader keeping command-line precedence.
- `rfy_hic2.sh --env_check` also checks perl, DBD::SQLite and java.

### Added (2.1.1)
- `utils/check_R_packages.sh`: every stage now verifies that the `Rscript` in
  PATH can load the packages it needs, and stops with a clear message
  (which Rscript, which library paths) instead of producing empty or truncated
  output files. A cluster `module load R` that hides the user library is the
  typical cause.
- `utils/Clean_sample_output.sh`: list (default) or delete the output of a
  sample from a given stage onwards, so a stage can be re-run from a clean
  state. Stage 2 output (alignment) is kept unless `--stage 2` is given.
- `6_make_hic_file.sh` stops on the first failure (missing chromosomes, empty
  short file, `pre` error, invalid .hic, bias/vector/addNorm failure) instead of
  writing an incomplete `.hic`.
- `utils/Verify_hic_file.R` reports why `juicer_tools dump` failed.

### Fixed
- `utils/Bias_normalization_ICE2.R` wrote the matrix with `append=TRUE`, so a
  leftover `ICE2/ALL.matrix` from an interrupted run was appended to instead of
  replaced, silently producing a corrupt matrix. Now written with
  `append=FALSE` (identical output in the normal case).
- All stage scripts: the argfile given with `--arg` was never read when a
  stage script was called directly (inverted test). Stages now work both via
  `rfy_hic2.sh` and as individual jobs.
- `rfy_hic2.sh`: `DIR_OUT` was undefined (`bash -eu` aborted at stage 5).
- `Make_association_from_fragmentdb_allChromosome.pl`,
  `_onlyIntraChr.pl`: read pairs located within one restriction fragment that
  spans a bin boundary were partly dropped (stored in the unread triangle of
  the matrix). They are now stored in canonical order. Effect on existing
  matrices is limited to bins next to the diagonal and is tiny
  (sum difference ~1e-5 in tests), but matrices recalculated with 2.1 can
  differ from 2.0 output at those cells.
