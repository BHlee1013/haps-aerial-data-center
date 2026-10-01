# Stage 2.1 hotfix - 2026-09-30

This hotfix responds to the first user-side MATLAB R2025b acceptance run of Stage 2.0. No paper result or reference CSV was changed.

## Runtime blocker fixed

- `validate_stage2.m` no longer relies on `M.model_file`/`M.sha256` table-variable names. The model manifest is read with `VariableNamingRule='preserve'` and its first two columns are consumed by position. This prevents locale/release-dependent variable-name normalization from breaking the structural check.
- `thermal_model_session.m` uses the same manifest handling so the subsequent real Simscape smoke test is protected from the same issue.

## MATLAB parser / Analyzer cleanup

- `load_burstgpt_pairs.m` no longer uses dynamic table-dot references such as `raw.(need(3))`; imported columns are accessed by explicit preserved header names and converted through a local numeric-column helper.
- `run_thermal_point.m`, `search_thermal_speed.m`, and `export_upstream_supplementary_tables.m` use explicit multi-line control-flow blocks.
- `thermal_model_session.m` uses distinct outer and cleanup-loop indices to avoid nested-function shared-variable diagnostics.

## Validation boundary

Independent Python checks still validate the stored numerical/source relationships only. MATLAB/Simulink/Simscape runtime acceptance must be repeated by the author from a clean extraction.
