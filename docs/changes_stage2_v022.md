# Stage 2.2 validation hotfix - 2026-09-30

This hotfix addresses issues observed during the first Windows/MATLAB R2025b
Stage-2 validation run.

## Fixed

1. **Model-manifest parsing**
   - `validate_stage2.m` and `thermal_model_session.m` no longer depend on
     `readtable` delimiter inference for `model_manifest.csv`.
   - A shared `read_model_manifest.m` helper parses the first two comma-separated
     fields explicitly and validates the SHA-256 format.
   - This fixes the Windows/Korean-locale failure where an entire CSV row was
     interpreted as a model filename.

2. **Simulink cleanup lifecycle**
   - `thermal_model_session.m` no longer gives `onCleanup` a nested function that
     references a mutable parent variable.
   - Models loaded by the session are captured only after successful loading;
     partial setup failures are restored in an explicit `catch` path.

3. **Stage-2 validation analyzer noise**
   - Stale `#ok<AGROW>` suppressions in `validate_stage2.m` were removed by using
     bounded preallocation for validation checks.

No reference CSV values, Simulink model bytes, thermal parameters, or manuscript
headline results were changed by this hotfix.
