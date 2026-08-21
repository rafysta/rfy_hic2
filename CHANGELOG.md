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

### Fixed
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
