# License scope

This repository intentionally uses different licenses for software and for
author-created non-software research materials.

## MIT License - software and models

The top-level `LICENSE` (MIT License) applies to the software created by
Byeongheon Lee in this repository, including:

- `code/**`
- `models/simscape/*.slx`
- top-level MATLAB entry points (`*.m`)
- `tools/*.py`

The MIT License permits use, modification, redistribution and commercial use
provided that the copyright and license notices are retained.

## CC BY 4.0 - author-created figures, documentation and data/results

The Creative Commons Attribution 4.0 International License applies to material
for which Byeongheon Lee holds the relevant rights, including:

- `figures/manuscript/**`
- repository documentation (`README.md`, `docs/**`, `supplementary/**`, and
  directory-level README files), except third-party quotations or reproduced
  third-party material
- author-generated analysis result tables and processed/result data in
  `data/**`, to the extent those files contain the author's original selection,
  transformation, annotations, derived quantities or analysis outputs

The CC BY 4.0 notice is in `LICENSES/CC-BY-4.0.txt`. A suggested attribution is:

> Byeongheon Lee, *HAPS aerial data center: cross-layer LLM inference
> reproduction code and data*, version 1.0.0 (2026).

## Third-party material is not relicensed

This repository does **not** grant rights to third-party source material merely
because a citation, parameter value, benchmark-derived input, or link appears in
the repository. In particular, the raw BurstGPT dataset is not redistributed.
NVIDIA NIM benchmark material, EARTH reference values, manufacturer
specifications, HAPS source documents, and MathWorks documentation remain
subject to their original terms.

See `THIRD_PARTY_NOTICES.md`, `docs/third_party_sources.csv`, and
`docs/input_provenance.md` for provenance and scope notes. If a file contains
both author-created analysis and facts derived from a third-party source, the
license above applies only to the portion for which the author can grant rights;
third-party rights, if any, are unaffected.
