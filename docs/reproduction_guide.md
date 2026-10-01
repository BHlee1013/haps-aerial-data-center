# Reproduction guide - v1.0.0

This guide separates fast integrity/reference checks from expensive raw, exact, Monte-Carlo and thermal computations. The public release was validated in MATLAB R2025b on the author's Windows system.

## 1. Fresh extraction and integrity check

Set MATLAB Current Folder to the repository root:

```matlab
restoredefaultpath;
rehash toolboxcache;
clear functions;
setup_haps;
rc = verify_release_candidate;
disp(rc.summary)
rc.passed
rc.publication_ready
```

Expected: both logical values are `true`. No scientific calculation is run by the integrity verifier.

## 2. Fast final reference validation

```matlab
qa = run_stage2_validation('MakeFigures', true);
disp(qa.summary)
qa.passed
```

The author-executed final run passed 41 structural/unit checks, 36 release checks and 200 serving comparisons. One Code Analyzer readability recommendation is expected in `test_workload_helpers.m`; it does not block acceptance.

This route loads packaged exact/MC/thermal reference outputs and generates numerical figures/tables. It does not execute raw BurstGPT processing, new Monte-Carlo sampling or new Simscape simulation.

## 3. Raw BurstGPT baseline and bootstrap

The raw CSV is not included. Use the exact local source file for which final release evidence records SHA-256 `2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f`.

Fast baseline regression:

```matlab
raw = validate_raw_workload_reproduction( ...
    'BurstGPTFile','D:\data\BurstGPT_3.csv');
disp(raw.checks)
raw.passed
```

Expected: 127,205 tau=1800 pairs and reference A-E counts/p_k/alpha_k.

Full paper workload path:

```matlab
work = run_workload_analysis( ...
    'BurstGPTFile','D:\data\BurstGPT_3.csv', ...
    'Tau',1800, ...
    'TauList',[600 1800 3600], ...
    'NumBootstrap',1000, ...
    'Seed',1, ...
    'MakeFigures',true);
```

The validated Session-ID policy is `exclude`: requests without usable Session IDs are not paired and no identity is imputed. Audit counts are written to `input_summary.csv`.

Final author evidence: 5,344,021 raw rows; 2,161,220 numeric-clean rows; 1,962,110 unusable Session IDs after numeric cleaning; 199,110 pairing-eligible requests; 146,682 consecutive-session pairs before tau filtering; 127,205 pairs at tau=1800 s; 110 day blocks.

## 4. Supplementary Table 6

```matlab
t6 = validate_supplementary_table6;
disp(t6)
```

All checks should pass. The manuscript export contains exactly `UA_ext = [300 350 400 500 600 750 1000] W/K`; the wider exploratory archive is retained separately.

## 5. Exact probability boundary check and optional full searches

```matlab
engine_check = validate_release('CheckExactEngine', true);
```

For deliberate full deterministic recomputation:

```matlab
analytical = run_full_reproduction('MakeFigures', false);
```

Pooled searches may be expensive. Raw, MC and Simscape computations are never started implicitly by this command.

## 6. Simscape boundary reproduction

The public release retains the already-passed two-point R2025b evidence. To rerun it deliberately:

```matlab
th = run_thermal_smoke_test;
disp(th.comparison)
th.reproduction_passed
```

This runs the reference model at 2650 and 2675 rpm with 5000 s model time each and a 500-s terminal tail. Expected classification: 2650 rpm converged but exceeds the chamber temperature limit; 2675 rpm converged and feasible.

Do not run all 1158 listed thermal study entries merely to test installation. Use `run_thermal_study(...,'Execute',false)` to inspect plans first.

## 7. Monte-Carlo validation

Small execution smoke test:

```matlab
mc = run_monte_carlo_validation('Mode','smoke');
```

Paper protocol, only when intentionally requested:

```matlab
mc_paper = run_monte_carlo_validation('Mode','paper','Protocol','both');
```

Monte Carlo is numerical validation, not the primary N95 estimator. Do not replace exact thresholds with finite-sample MC thresholds.

## 8. Validation evidence and interpretation

Actual author runs are under `docs/validation_evidence/`. See `validation_status.md` for what was executed and what remains archived rather than freshly rerun.

The package does not claim flight qualification, mixed-workload hardware validation, geographic coverage guarantees or whole-aircraft energy superiority. High-rpm thermal points are model-envelope sensitivities.
