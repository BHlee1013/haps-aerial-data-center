# 0.2.3-rc1: metadata and figure/evidence integration

Base: `haps-aerial-data-center_stage2_v022_20260930.zip`.

## Preserved

All 51 inherited MATLAB files, all 3 inherited Python files, all 115 numerical
CSV files, both SLX models and the model CSV manifest are byte-identical to the
Stage 2.2 base. No probability definition, random seed, thermal input, solver
setting, source/reference value or scientific tolerance was changed.

## Updated or added

- Coherent release version in VERSION, README, CITATION.cff and release_status.
- Runtime status updated from pending to the specific scope supported by the
  author's supplied R2025b bundle; unexecuted routes remain explicitly unexecuted.
- Both actual runtime snapshots and all 120 submitted evidence files included.
- 29 manuscript figure assets organized and hashed without modifying their bytes.
- Current figure-to-data/code index and publication checklist.
- Source citations transcribed from the supplied manuscript/SI. No online source
  revision or NIM row provenance was fabricated.
- Updated auxiliary-parity entry in generated_reference_manifest.json to the
  existing Stage 2.2 semantic-column schema/hash. Its historical manifest remains
  available; numerical CSV bytes were not changed.
- Separate MATLAB and standard-library Python integrity-only verifiers.
- Recomputed release checksum list; incidental Python bytecode cache excluded.

The setup banner is intentionally unchanged (Stage 2.2 computational engine).
The publication license notice is not converted into a grant of rights.
The known repository URL was already author-supplied; its current visibility
was not checked, and no upload, Git tag, publication or DOI creation was made.
