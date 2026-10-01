# Release notes - v1.0.0

First public release of the HAPS aerial data-center reproduction package.

## Final corrections validated before release

- Corrected manuscript Fig. 5d and assembled Fig. 5 to the 1.275-kW IT normalization already defined by the paper and numerical source CSV; the scaled fan contribution is approximately 10.0081 W.
- Made the raw BurstGPT Session-ID policy explicit: requests without a usable Session ID are excluded from session-pair construction and no identity is imputed.
- Added raw-input audit counts and regression tests for missing/empty/whitespace Session IDs.
- Corrected Supplementary Table 6 export to the seven manuscript `UA_ext` values (300, 350, 400, 500, 600, 750 and 1000 W/K), while preserving the wider ten-row exploratory archive separately.
- Added direct validation that each Supplementary Table 6 row is the best result for its `UA_ext` among the archived 84 C2 cases.

## Author-executed final validation

- Raw BurstGPT SHA-256: `2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f`.
- `tau=1800 s` valid request pairs: 127,205.
- Full-precision `p_k` and `alpha_k`: reproduced to floating-point precision.
- 1,000-replicate day-level bootstrap (seed 1): Supplementary Table 1 intervals reproduced.
- `tau=600/1800/3600 s` sensitivity: Supplementary Table 2 values reproduced.
- Final figure-enabled Stage-2 run: 41 structural/unit checks, 36 release checks and 200 serving comparisons passed.
- One MATLAB Code Analyzer style recommendation remains intentionally unchanged because it has no functional effect and the validated source is frozen.
- Earlier R2025b two-point Simscape validation at 2650/2675 rpm remains valid for the unchanged thermal code/model and reproduced the expected boundary.

## Licensing

- Software and Simscape models: MIT License.
- Author-created figures/documentation and author-generated processed/result data: CC BY 4.0, subject to the third-party exclusions documented in the repository.

## Archival DOI

No Zenodo DOI is included in this archive because it has not yet been assigned. Create GitHub tag/release `v1.0.0`, archive that release with Zenodo, and then add the issued DOI to the manuscript and, optionally, a follow-up repository commit.
