# Supplementary source-data coverage

| Paper item | Reproduction source | Final runtime evidence |
|---|---|---|
| Table 1 | Raw workload/activity/bootstrap path | **1000-replicate raw bootstrap rerun reproduced the reported intervals** |
| Table 2 and Fig. 1 | Full-precision tau route; rounded display table for presentation only | **Raw tau=600/1800/3600 run reproduced the reported values** |
| Tables 3-4 | NIM/SLO extraction and nominal interpolation | Final serving reference comparisons pass |
| Tables 5-8 | Archived high-load, corner and duration thermal results | Exports checked; separate 2650/2675-rpm reference simulations are retained runtime evidence |
| Table 6 specifically | Seven manuscript UA_ext rows selected from the C2 envelope | **Seven-row scope and best-by-UA checks pass in final MATLAB validation** |
| Tables 9-10 | Current exact activity and engineering allocation | Final downstream reference route passes |
| Tables 11-12 and Fig. 3 | Exact pooled/static tables and neutral linear reference | Stored exact results exported; exhaustive searches not rerun solely for packaging |
| Tables 13-14 and Fig. 2 | Full-precision mapping table and exact mapping outputs | Stored results exported; raw baseline mapping inputs reproduced |
| Table 15 and Fig. 4 | Pooled MC curves and fully bracketed seed diagnostics | Stored statistics checked/replotted; no new final 20-seed sampling |

`run_reference_reproduction` / `run_stage2_validation` exports numerical CSVs and optional figures; it does not regenerate the LaTeX Supplementary PDF. The final author runtime outputs are preserved in `docs/validation_evidence/`.

The wider ten-row high-load envelope remains an archived exploratory result. `supp_table06_codesign_envelope.csv` is intentionally the seven-row manuscript subset `[300,350,400,500,600,750,1000] W/K` and is validated against the 84-case C2 summary.

The rounded tau presentation table must not enter downstream reliability calculations. Independent-seed MC variability is not a workload confidence interval or seed dependence of exact-under-model N95.

## Licensing

Author-created supplementary documentation is CC BY 4.0. Numerical source data follow `../LICENSE-DATA-MEDIA.md`; third-party source material is not relicensed.
