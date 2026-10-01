# HAPS aerial data center

Reproduction code and source data for **Direct wireless large language model inference from high-altitude platform stations under payload constraints**, by Byeongheon Lee and Young-Chai Ko.

**Manuscript status:** The manuscript is currently under preparation/submission. The manuscript PDF is not distributed in this repository because the text and layout may still change. The final publication DOI will be linked here when available.


**Release: v1.0.0.** This package is the public-release build prepared after the final author-side MATLAB R2025b validation. The scientific code, numerical reference data, Simscape models and manuscript figures in this archive are the validated versions used for release. A Zenodo DOI is intentionally absent until the GitHub `v1.0.0` release is archived.

## Final validation status

The final author-side validation completed successfully on 2026-09-30.

- Raw BurstGPT input: 5,344,021 rows; SHA-256 `2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f`.
- After numeric cleaning: 2,161,220 rows.
- Requests without usable Session IDs after numeric cleaning: 1,962,110. These requests are excluded from session-pair construction; no Session ID is imputed.
- Pairing-eligible requests: 199,110; consecutive-session pairs before the tau filter: 146,682.
- Final `tau = 1800 s` valid request pairs: **127,205**.
- Regenerated full-precision workload occupancy `p_k` and activity fractions `alpha_k` agree with the packaged reference to floating-point precision.
- Day-level bootstrap: 1,000 replicates with seed 1; Supplementary Table 1 intervals reproduced.
- Session-threshold sensitivity at 600/1800/3600 s reproduced Supplementary Table 2.
- Final Stage-2 reference validation: **41/41 structural/unit checks**, **36/36 release checks**, **200/200 serving comparisons**, `passed = true`.
- MATLAB Code Analyzer reported one style-only recommendation in `test_workload_helpers.m` (`repmat(1,x,y)` could be written as `ones(x,y)`); it does not affect execution or numerical results and the validated source is left unchanged.
- Supplementary Table 6 export is restricted to the seven manuscript values `UA_ext = [300, 350, 400, 500, 600, 750, 1000] W/K` and each row is validated against the 84-case C2 archive.
- Fig. 5d and assembled Fig. 5 use the corrected 1.275-kW IT normalization with scaled fan power `10.0081046 W`.
- The previously executed Simscape reference-model smoke test at 2650 and 2675 rpm remains the thermal runtime evidence: both 5000-s runs converged and reproduced the expected infeasible/feasible boundary.

Evidence is preserved under `docs/validation_evidence/`; see `docs/validation_status.md` for the exact scope and limitations.

## Licensing

- MATLAB/Python software and Simscape models: **MIT License**.
- Author-created figures, documentation, and author-generated processed/result data: **CC BY 4.0**.
- Raw BurstGPT and cited third-party benchmark/specification documents are not redistributed or relicensed.

See `LICENSE`, `LICENSE-DATA-MEDIA.md`, and `THIRD_PARTY_NOTICES.md`.

## Quick integrity check

Extract the archive into a new folder. In a fresh MATLAB session, set Current Folder to the repository root and run:

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

For the final package, both values should be `true`. This check verifies packaged hashes and the retained computational baseline; it does **not** rerun exact searches, Monte Carlo, raw processing, or Simscape.

The inherited `setup_haps` banner still says **Stage 2.2** because the validated computational file is intentionally not edited merely to change its banner. `VERSION` and `CITATION.cff` identify the public package as `1.0.0`.

An equivalent integrity-only check is available with Python standard library only:

```text
python tools/verify_release_candidate.py
```

## Main reproduction entry points

```matlab
% Fast reference-based numerical reproduction and figures.
qa = run_stage2_validation('MakeFigures', true);

% Raw BurstGPT reproduction (raw CSV is not bundled).
work = run_workload_analysis( ...
    'BurstGPTFile', 'D:\data\BurstGPT_3.csv', ...
    'Tau', 1800, ...
    'TauList', [600 1800 3600], ...
    'NumBootstrap', 1000, ...
    'Seed', 1, ...
    'MakeFigures', true);

% Targeted raw baseline regression.
raw = validate_raw_workload_reproduction('BurstGPTFile','D:\data\BurstGPT_3.csv');

% Supplementary Table 6 scope/optimum check.
t6 = validate_supplementary_table6;

% Previously validated two-point Simscape migration smoke test.
th = run_thermal_smoke_test;
```

Do not begin by rerunning all thermal cases or Monte-Carlo seeds merely to test installation. See `docs/reproduction_guide.md` for staged reproduction paths and their expected scope.

## Repository layout

```text
code/workload/              BurstGPT pairing, mapping, bootstrap and tau sensitivity
code/serving_capacity/      NIM/SLO capacity extraction and interpolation
code/communication/         active-user, link-budget and radio-power analysis
code/thermal/               Simscape parameterization and thermal studies
code/haps_feasibility/      exact reliability, payload deployment and fleet sizing
code/figures/               manuscript/SI numerical figure and table exports
code/validation/            structural, numerical and raw-data regression checks
data/processed/             canonical processed numerical inputs
data/results/reference/     immutable study reference outputs
models/simscape/            reference and map SLX snapshots
figures/manuscript/         author-created manuscript figure assets
docs/validation_evidence/  author-executed MATLAB/Simscape evidence
supplementary/              SI coverage and interpretation notes
```

## Important interpretation notes

The primary `N95` values are obtained by direct evaluation of the adopted independent Binomial activity model, not by finite Monte Carlo. Monte Carlo is numerical validation only. Linear `m*N95`, pooled exact capacity and static balanced-assignment capacity are distinct quantities. Fleet sizing is compute-capacity dimensioning rather than a geographic-coverage guarantee.

The raw BurstGPT trace is not bundled. Requests without usable Session IDs are excluded from session-pair construction with no identity imputation. The author-executed raw reproduction demonstrates that this explicit policy recovers the paper's 127,205 tau=1800 pairs and full-precision `p_k`/`alpha_k` values.

Thermal results above the preferred 5000-rpm range are model-envelope sensitivities, not flight-qualified fan operating points. The archived thermal failures are retained as simulation failures rather than silently converted to physical infeasibility.

## Publication

Repository URL: `https://github.com/BHlee1013/haps-aerial-data-center`

After uploading this package, create Git tag and GitHub Release `v1.0.0`, then archive that release with Zenodo. Add the DOI issued by Zenodo to the manuscript Code Availability statement. Do not fabricate or prefill a DOI before Zenodo assigns one.
