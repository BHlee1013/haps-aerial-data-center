# v1.0.0 final release changes

The final public package promotes the runtime-validated `1.0.0-rc2` source to `v1.0.0` without changing scientific code, canonical result CSVs or SLX model bytes after validation.

## Scientific/reproducibility corrections already validated in RC2

- Explicitly exclude requests without usable BurstGPT Session IDs from session-pair construction; do not impute or merge unknown identities.
- Add Session-ID edge-case tests and raw workload regression.
- Restrict Supplementary Table 6 manuscript export to seven UA_ext values while preserving the wider exploratory archive.
- Validate each Table 6 row against the 84-case C2 best-by-UA result.
- Replace stale manuscript Fig. 5d / assembled Fig. 5 with the correct 1.275-kW normalization.

## Final author runtime evidence added

- Original raw BurstGPT regression reproducing 127,205 tau=1800 pairs and full-precision p_k/alpha_k.
- 1,000-replicate day-level bootstrap (seed 1) reproducing Supplementary Table 1 intervals.
- Tau sensitivity at 600/1800/3600 s reproducing Supplementary Table 2.
- Figure-enabled final Stage-2 validation: 41 structural/unit checks, 36 release checks and 200 serving comparisons all pass.
- One non-functional MATLAB Code Analyzer readability recommendation is documented and left unchanged to preserve the validated source bytes.

## Release metadata

- Version promoted from `1.0.0-rc2` to `1.0.0`.
- MIT applies to software/Simscape models.
- CC BY 4.0 applies to author-created figures/documentation and author-generated processed/result data, subject to third-party exceptions.
- Zenodo DOI remains intentionally absent until the public GitHub release is archived.
- Package checksum and validation-evidence manifests are regenerated for the final archive.
