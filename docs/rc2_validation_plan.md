# v1.0.0-rc2 author validation plan

This candidate intentionally changes the raw workload loader and the Supplementary Table 6 export path. The public v1.0.0 tag should be created only after the following MATLAB checks pass on the author's machine.

## 1. Fresh path and Code Analyzer

```matlab
restoredefaultpath;
rehash toolboxcache;
clear functions;
setup_haps;
issues = check_matlab_code;
```

Parser/syntax errors are blockers. Performance/style warnings should be reviewed but are not automatically numerical failures.

## 2. Fast structural/unit validation

```matlab
extra = validate_stage2;
disp(extra)
```

RC2 is expected to include the expanded missing-Session-ID tests and the Supplementary Table 6 source checks.

## 3. Raw BurstGPT baseline regression - required

Select the same original BurstGPT CSV used for the study and run:

```matlab
[fileName,folderName] = uigetfile('*.csv','Select original BurstGPT_3.csv');
rawFile = fullfile(folderName,fileName);
raw = validate_raw_workload_reproduction('BurstGPTFile',rawFile);
disp(raw.checks)
raw.passed
```

Acceptance requires:

- tau=1800 pair count = 127,205;
- A-E distance-mapped pair counts exactly match the packaged reference;
- full-precision p_k matches within 1e-12;
- full-precision alpha_k matches within 1e-12;
- A-E range-pair counts exactly match the packaged reference.

This first regression runs with zero bootstrap replicates. If it fails, do not overwrite reference CSVs; preserve the generated output directory and inspect the first failed check.

## 4. Table 6 check

```matlab
t6 = validate_supplementary_table6;
disp(t6)
```

The selected UA_ext values must be exactly 300, 350, 400, 500, 600, 750 and 1000 W/K and must agree with the per-UA minima in the archived 84-case C2 summary.

## 5. Optional full workload/bootstrap rerun

After step 3 passes, the full 1,000-replicate workload route may be run if desired:

```matlab
fullWork = run_workload_analysis( ...
    'BurstGPTFile',rawFile, ...
    'NumBootstrap',1000, ...
    'Seed',1, ...
    'MakeFigures',true);
```

This is not required to revalidate unchanged Simscape or exact-reliability code if the baseline p_k/alpha_k are unchanged.

## 6. What does not need to be rerun for this candidate

The reference Simscape 2650/2675-rpm smoke test, full thermal sweeps, exact threshold searches and Monte-Carlo validation do not need to be rerun solely because of the Session-ID/Table-6/Fig.-5d corrections, provided step 3 reproduces the existing full-precision workload inputs.
