# Input provenance

## BurstGPT raw workload

The raw BurstGPT trace is **not redistributed** in this repository. The author executed the final workload reproduction on the original local `BurstGPT_3.csv`; the runner recorded:

- SHA-256: `2299986a07388aa303ec2c41d1131e756db650a39ed6ef9dfe7cc3d7f9a43b8f`
- raw rows: 5,344,021
- numeric-clean rows: 2,161,220
- requests without usable Session IDs after numeric cleaning: 1,962,110
- pairing-eligible requests: 199,110
- consecutive-session pairs before tau filtering: 146,682
- tau=1800 s valid pairs: 127,205
- unique sessions among pairing-eligible records: 52,428
- day blocks: 110

Requests without a usable Session ID are excluded from session-pair construction and no identity is imputed. This explicit policy reproduces the paper's A-E counts and full-precision p_k/alpha_k values. Runtime evidence is under `docs/validation_evidence/raw_workload_20260930/`.

The upstream BurstGPT source is cited in the manuscript. The repository records the exact local input hash used for final reproduction; it does not redistribute the raw rows or infer an unavailable upstream commit identifier.

## NIM and other third-party inputs

`source_manifest.csv` and `stage2_source_manifest.csv` link archived local sources to public release paths and hashes. `nim_provenance_index.csv` indexes extracted benchmark rows to the local input CSV. Documentation release 1.0.0 and NIM container results 1.8.0 are separate identifiers, as stated in the manuscript.

EARTH, DGX, L40S and HAPS platform assumptions retain the study's cited values. `third_party_sources.csv` records the cited titles/URLs/access dates. The repository does not claim redistribution rights for source benchmark documents or manufacturer materials and does not silently replace them with newer specifications.

## Evidence hierarchy

- `data/processed/` and `data/results/reference/`: canonical packaged numerical inputs/results.
- `docs/validation_evidence/`: actual author-executed MATLAB/Simscape outputs used to validate the migrated release.
- `docs/release_file_checksums.csv`: complete final package inventory/hash list.
- `docs/frozen_computational_files.csv`: retained inherited computational baseline subset used by the lightweight integrity verifier.

Some historical third-party page/snapshot revisions cannot be reconstructed beyond the evidence listed above. Those limitations are disclosed rather than guessed.

## Publication identity

Repository URL: `https://github.com/BHlee1013/haps-aerial-data-center`.

Software/Simscape: MIT. Author-created figures/documentation and author-generated processed/result data: CC BY 4.0, subject to third-party exclusions. A Zenodo DOI is intentionally not fabricated; it will be added after the actual GitHub `v1.0.0` release is archived.
