# Data inputs and reference outputs

`processed` holds canonical source-derived numerical inputs. `results/reference` is immutable to MATLAB output helpers. New runs go to timestamped directories under `results/generated`, which is ignored by Git.

## Raw BurstGPT

The raw BurstGPT trace is not bundled or relicensed. The final author-side reproduction used a local `BurstGPT_3.csv` with SHA-256:

`2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f`

The validated preprocessing produced 127,205 request pairs at tau=1800 s and reproduced the packaged full-precision p_k/alpha_k values. Requests without usable Session IDs are excluded from session-pair construction; no identity is imputed. Final bootstrap/tau evidence is under `docs/validation_evidence/raw_workload_20260930/`.

The small `tau_sensitivity_display_reference.csv` remains a manuscript-rounded presentation reference and never feeds a capacity calculation; the raw final run produced the full-precision 600/1800/3600 values separately.

## Thermal reference data

`thermal_cases.csv` contains 1158 study entries with absolute parameters; repeated reference designs are intentionally included. Do not multiply absolute areas by duct scale again. `thermal_smoke_checkpoints.csv` preserves archived successful 2650/2675-rpm outputs.

The `results/reference/thermal` subfolders preserve archived source CSV bytes, including solver-failure rows and legacy filenames. The wider high-load exploratory envelope is preserved; manuscript Supplementary Table 6 is exported as the validated seven-row subset.

## NIM / communication / hardware inputs

NIM, EARTH and hardware model inputs retain the study definitions. Source-to-row/version limitations are documented rather than guessed. Refer to `docs/source_manifest.csv`, `docs/input_provenance.md`, `docs/third_party_sources.csv`, and `THIRD_PARTY_NOTICES.md`.

## Licensing

Author-generated processed/result data are CC BY 4.0 as scoped in `../LICENSE-DATA-MEDIA.md`. Tables containing facts or values derived from third-party sources do not relicense those sources. Raw BurstGPT is not redistributed.
