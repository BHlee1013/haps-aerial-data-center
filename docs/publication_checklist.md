# Publication checklist for v1.0.0

All scientific/code release gates that required author-side execution have been completed for this package. Remaining items are publication actions, not unresolved numerical validation.

| Gate | State | Notes / next action |
|---|---|---|
| Raw BurstGPT Session-ID policy | **PASS** | Requests without usable IDs are excluded with no identity imputation |
| Raw tau=1800 workload regression | **PASS** | 127,205 pairs; A-E counts and full-precision p_k/alpha_k reproduced |
| 1,000-replicate bootstrap | **PASS** | Seed 1; Supplementary Table 1 intervals reproduced |
| Tau sensitivity 600/1800/3600 s | **PASS** | Supplementary Table 2 values reproduced |
| Supplementary Table 6 scope | **PASS** | Exactly seven manuscript UA_ext values; each matches C2 best-by-UA |
| Fig. 5d normalization/artwork | **PASS** | 1.275-kW normalization and corrected panel/composite included |
| Final figure-enabled Stage-2 validation | **PASS** | 41 structural/unit, 36 release, 200 serving comparisons |
| Reference Simscape boundary test | **PASS** | Previously executed 2650/2675-rpm, 5000-s evidence retained |
| Software / Simscape license | **APPROVED** | MIT License |
| Figures / docs / author-generated data license | **APPROVED** | CC BY 4.0, subject to third-party exclusions |
| Third-party material | **DISCLOSED / NOT RELICENSED** | Raw BurstGPT and source benchmark/spec documents are not redistributed |
| Repository URL | **RECORDED** | https://github.com/BHlee1013/haps-aerial-data-center |
| Package integrity check | **RUN LOCALLY BEFORE UPLOAD** | `setup_haps; rc=verify_release_candidate; rc.passed; rc.publication_ready` |
| GitHub v1.0.0 release | **NEXT ACTION** | Commit package contents, tag and create release `v1.0.0` |
| Zenodo archive DOI | **PENDING BY DESIGN** | Archive GitHub v1.0.0 release; use DOI issued by Zenodo |

The raw BurstGPT file itself is not bundled. Its validated SHA-256 is `2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f`.

Some third-party historical page/snapshot identifiers are only known to the extent recorded in `input_provenance.md`; the repository does not invent unavailable revisions. This is disclosed provenance, not a blocker to the validated software/data release.

After Zenodo issues the DOI, update the manuscript Data/Code Availability statements. Optionally add the DOI to README/CITATION in a follow-up commit or patch release; do not rewrite an already archived `v1.0.0` tag solely to insert the DOI.
