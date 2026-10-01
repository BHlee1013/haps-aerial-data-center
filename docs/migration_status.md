# Integration and runtime coverage at v1.0.0

Source collection, public-code integration and the targeted final runtime validations are complete for the public `v1.0.0` package. This does not mean every expensive search/sweep was newly executed after the final code cleanup; the table below distinguishes the actual evidence.

| Area | Integrated material | Runtime evidence for v1.0.0 |
|---|---|---|
| Workload / bootstrap / tau / mapping | Raw-data path, Session-ID policy, occupancy/range mapping, bootstrap, tau sensitivity | **Full raw run completed:** 127,205 tau=1800 pairs, p_k/alpha_k regression pass, 1,000 bootstrap replicates and tau sensitivity reproduced |
| Serving / SLO / interpolation | Five SLOs, four crossing methods | Final reference route: 200 archived serving comparisons pass |
| Exact reliability | Single/pooled/static and mapping searches | Source/stored thresholds checked; no new exhaustive final search solely for packaging |
| Communication / payload | Exact activity inputs, 1.275-kW parity normalization, L40S limit logic | Final MATLAB reference route passes; generated Fig. 5d values confirmed |
| Thermal reference | Reference SLX and explicit-input runner | Earlier two 5000-s boundary runs pass; unchanged thermal bytes in final package |
| Thermal map / high loads | Map SLX, archived full grids and unified searches | Source/hash/archive checks; no complete new final sweep |
| MC validation | Pooled and independent protocols plus frozen diagnostics | Stored statistics checked/replotted; no new 20-seed sampling after RC2 |
| Main/SI numerical figures | Source-value exports | Final figure-enabled Stage-2 reference run completed |
| Manuscript Fig. 5d | Corrected panel/composite | Corrected 1.275-kW artwork included and visually reviewed |
| SI Table 6 | Seven-row manuscript export plus wider archived envelope | Final MATLAB scope/best-by-UA validation passes |
| Release metadata | Version, licenses, validation evidence and hashes | Ready for GitHub v1.0.0; Zenodo DOI pending |

The raw BurstGPT trace is intentionally not redistributed. See `validation_status.md` and `publication_checklist.md` for the release evidence and remaining publication steps.
