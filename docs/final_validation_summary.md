# Final v1.0.0 validation summary

Date: 2026-09-30

## Release decision

**PASS for public GitHub v1.0.0 release.** The targeted issues discovered during release audit were corrected and validated on the author's MATLAB R2025b system.

## Closed issues

1. **Fig. 5d normalization:** corrected to the 1.275-kW IT reference with fan power 10.0081046 W; corrected panel and assembled Fig. 5 are packaged.
2. **BurstGPT missing Session IDs:** explicit exclusion policy validated on the original raw trace; no Session ID is imputed. The paper baseline is reproduced exactly to numerical precision.
3. **Supplementary Table 6 scope:** manuscript export contains seven UA_ext rows only and each row matches the archived 84-case C2 best-by-UA result.

## Final author runs

- Raw workload full run: 127,205 tau=1800 pairs, 1,000 bootstrap replicates, tau sensitivity, figures.
- Final reference route with figures: overall pass, 41/41 structural/unit checks, 36/36 release checks, 200/200 serving comparisons.
- Previously retained thermal migration test: 2650/2675-rpm reference points pass.

## Remaining post-release action

Create GitHub tag/release `v1.0.0`, archive it with Zenodo, then insert the issued DOI in the manuscript Data/Code Availability statements. The DOI is intentionally absent from this pre-archive package.
