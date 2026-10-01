# Changes in v1.0.0-rc2 validation candidate

This candidate repairs three release-path issues found after the initial v1.0.0 packaging audit.
It is intended for author-side MATLAB validation before the public v1.0.0 tag is created.

## Changed scientific/reproduction files

1. `code/workload/load_burstgpt_pairs.m`
   - Requests without a usable Session ID are excluded from session-pair construction by default.
   - No session ID is imputed, shared, or forward-filled.
   - Exclusion counts and the active policy are recorded in the returned import summary.
   - `MissingSessionPolicy='error'` retains an explicit strict audit mode.
2. `code/workload/run_workload_analysis.m`
   - Documents the missing-session policy; numerical equations are unchanged.
3. `code/validation/test_workload_helpers.m`
   - Adds missing/empty/whitespace Session ID regression tests and strict-mode tests.
4. `code/validation/validate_raw_workload_reproduction.m`
   - New author-side raw-trace regression route. It runs with no bootstrap and checks the 1800-s pair count, A-E counts, full-precision p_k, alpha_k and range-pair counts against the packaged reference.
5. `code/figures/export_upstream_supplementary_tables.m`
   - Supplementary Table 6 now exports exactly UA_ext = 300, 350, 400, 500, 600, 750 and 1000 W/K. The wider ten-row exploratory best-by-UA archive is retained unchanged.
6. `code/validation/validate_supplementary_table6.m` and `validate_stage2.m`
   - Add explicit source checks for the seven-row manuscript Table 6 envelope.

## Figure correction

- `figures/manuscript/panels/Fig5d.pdf` is the author-corrected 1.275-kW panel.
- `figures/manuscript/main/Fig5.pdf` is cropped from the author's corrected 2026-09-30 17:38 manuscript page so the archived composite no longer contains the stale 1.1-kW-normalized panel.
- No communication or thermal numerical input was changed for this figure correction.

## Raw trace diagnostic motivating the loader repair

The author-run diagnostic on the original BurstGPT CSV reported:

- raw rows: 5,344,021
- numeric-clean rows: 2,161,220
- unusable Session IDs after numeric cleaning: 1,962,110
- pairing-eligible rows: 199,110
- former released loader would raise `HAPS:MissingSession`: true

These counts do not by themselves establish that the paper statistics change. The required acceptance test is `validate_raw_workload_reproduction`, which must reproduce the archived tau=1800 baseline before this candidate is promoted to public v1.0.0.
