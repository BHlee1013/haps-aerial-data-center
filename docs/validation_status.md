# Validation status for v1.0.0

The public `v1.0.0` package is built from the runtime-validated `1.0.0-rc2` source. No scientific code, canonical result CSV or SLX model was changed after the final RC2 MATLAB validation. Final packaging changes are documentation, validation evidence, version metadata and checksum manifests.

## Final author-executed MATLAB validation

### Raw BurstGPT reproduction

The author executed the raw-data path in MATLAB R2025b on the original `BurstGPT_3.csv`.

| Item | Result |
|---|---:|
| Raw rows | 5,344,021 |
| Numeric-clean rows | 2,161,220 |
| Unusable Session IDs after numeric cleaning | 1,962,110 |
| Pairing-eligible requests | 199,110 |
| Consecutive-session pairs before tau filtering | 146,682 |
| tau=1800 s valid request pairs | **127,205** |
| Unique sessions | 52,428 |
| Day blocks | 110 |
| Raw SHA-256 | `2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f` |

Requests without usable Session IDs are excluded from session-pair construction; no identity is imputed. The regenerated A-E pair counts, range-pair counts, full-precision `p_k` and full-precision `alpha_k` agree with the packaged reference. Maximum differences are at floating-point roundoff scale.

The full run also executed 1,000 day-level bootstrap replicates with seed 1 and the tau sensitivity at 600, 1800 and 3600 s. Supplementary Table 1 confidence intervals and Supplementary Table 2 rounded activity values were reproduced.

Evidence: `docs/validation_evidence/raw_workload_20260930/workload_20260930_182242_310/`.

### Final figure-enabled reference validation

The author then executed `run_stage2_validation('MakeFigures', true)` on RC2.

| Check | Result |
|---|---:|
| Overall acceptance | **PASS** |
| Structural/unit checks | **41/41** |
| Release checks | **36/36** |
| Serving comparisons | **200/200** |
| Figures requested | yes |
| Code Analyzer messages | 1 style-only recommendation |
| Thermal simulation in this run | no |
| Monte-Carlo sampling in this run | no |
| Raw trace processing in this run | no |

The sole Code Analyzer message recommends replacing `repmat(1,x,y)` by `ones(x,y)` in a test helper for readability. It is not a parser, execution or numerical error. The validated source is intentionally left unchanged for the public package.

The generated Supplementary Table 6 contains exactly the seven manuscript UA values (300, 350, 400, 500, 600, 750, 1000 W/K), and the validation confirms that each is the minimum-overhead entry for that UA among the archived 84 C2 cases.

The generated Fig. 5d data use `P_IT = 1275 W` and `P_fan = 10.0081045947057 W`. The author-created panel and assembled manuscript Fig. 5 in `figures/manuscript/` were corrected to the same normalization.

Evidence: `docs/validation_evidence/final_rc2_20260930/stage2_validation_20260930_182826_330/`.

## Simscape runtime evidence retained from the validated Stage 2.2 migration

The unchanged reference SLX was previously run at 2650 and 2675 rpm for 5000 s each in MATLAB/Simulink/Simscape R2025b. Both runs succeeded and converged. The 2650-rpm point exceeded the chamber-temperature limit as expected; the 2675-rpm point was feasible. This remains valid evidence because the thermal source/model bytes were not changed by RC2 or final packaging.

Observed values:

| rpm | status | server tail K | chamber tail K | electrical fan W |
|---:|---|---:|---:|---:|
| 2650 | temperature_limit_exceeded | 322.971699993111 | 300.132690135285 | 8.38111004645123 |
| 2675 | feasible | 322.340421264883 | 299.496037906895 | 8.63444317992529 |

Evidence: `docs/validation_evidence/r2025b_20260930/thermal_smoke_20260930_153018_795/`.

## What is not claimed as a fresh final rerun

- A new exhaustive exact single/pooled/static search of every configuration after RC2. The inputs are unchanged and the reference-route checks pass, but the expensive searches were not repeated solely for packaging.
- New 20-seed Monte-Carlo sampling after RC2. Stored MC results remain numerical validation only.
- A complete new 957-case thermal map or every higher-load thermal sweep under the unified runner.
- A new runtime execution of the distinct map SLX.
- Flight qualification or hardware validation beyond the assumptions stated in the manuscript.

These limits are intentional and documented; they do not negate the targeted final validations above.
