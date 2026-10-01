# Figure files and data provenance

`manuscript/` contains the author's supplied publication-layout assets, unchanged
at the byte level. These are not newly generated analysis outputs. The original
archive member path, public path, size, SHA-256, code entry and numerical source
are listed in `../docs/figure_manifest.csv`.

```
manuscript/main/       Fig1.pdf ... Fig6.pdf (6 assembled figures)
manuscript/panels/     20 numerical panel PDFs (Fig2a ... Fig6e)
manuscript/artwork/    Fig1ab.png, Fig1c.png, Fig4a.png
```

The original uppercase `.PNG` extension of Fig1c was normalized to `.png`; its
bytes did not change. Main/panel PDF names remain the familiar author names.
All 29 files were read/rendered or inspected; key current exact labels in
Fig3d/3e, Fig5a and Fig6a/6d/6e were checked. This is a source/layout review, not
pixel-level digitization or proof of the code-to-original graphical edit history.
No raster image was converted into a claimed vector original.

Generated numerical panels and source-value CSVs go under the respective run's
`data/results/generated/.../figures/`. Actual prior generated PNGs are included
under `docs/validation_evidence/`, distinct from the manuscript originals.
No original figure is a hidden numerical input, and no numeric output was replaced
by a value inferred from a PDF.

Fig1/Fig4a are conceptual drawings, not numerical algorithms. The newly supplied
Fig2a PDF preserves the author's visual result; reproducing its histogram still
requires raw BurstGPT and `run_workload_analysis`. The final SI figure originals
were not in this upload; the numerical SI paths and observed PNG exports remain
available without asking for another mandatory figure upload.

Small fonts/crop margins and visual styling in originals are retained as supplied;
review at final journal print size. The author has confirmed ownership of the supplied manuscript figures/artwork.
These author-created assets are released under CC BY 4.0; see
`../LICENSE-DATA-MEDIA.md`.
