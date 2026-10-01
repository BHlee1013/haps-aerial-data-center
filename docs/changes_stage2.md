# Stage 2 changes and model-preservation boundaries

The Stage-1 user-tested analytical path is retained. Known unreachable/unused
communication code was removed, repeated scenario/row allocation was preallocated,
and the traffic-reference model is separated from the Fig.5d IT-normalization
model. Other Code Analyzer diagnostics must be assessed in the user's MATLAB
release; no zero-warning result is claimed here.

## Added modules

- Raw BurstGPT loader, stable string-session pairing, shared distance/range
  classifier, activity estimator, daily-sufficient-statistic alpha bootstrap,
  tau sensitivity, mapping inputs and token density.
- Five SLOs and four interpolation methods. PCHIP retains the source's **inverse
  latency-to-concurrency** convention. Nominal interpolation sensitivity stops
  at Cmix/Nharm; old interpolation-dependent MC N95 is not promoted to primary.
- A common absolute thermal case grid, explicit model selection, two renamed
  byte-identical SLX files, single-point execution, adjacent-checkpoint smoke
  test, gated sweep, and final-summary-only high-load reporting.
- Separate pooled and fully bracketed MC regeneration. Smoke and paper settings
  are explicit; seed paths and missing brackets are saved.
- Upstream/thermal numerical plots, SI1-8 exports, safe acceptance/bundle helpers.

## Thermal scope

The two SLX payloads are byte-identical to source except for their external file
names. No blocks, port connectivity, fan curves or solver settings were edited.
Their load/compile/runtime behavior under the new file names remains to be tested
in MATLAB. The duplicated high-load model has the same SHA-256 as the reference
model, so only one shared copy is needed. The map model remains separate.

The parameter CSV uses absolute areas; the selected 1.5-times duct geometry is
not multiplied again. High-load absolute parameters were reconstructed from the
archived case summaries and the shared source setter. These mappings are checked
against source inputs. The 5000-s source SLX StopTime and 1x/2x duration factors
become explicitly recorded requested durations; older CSVs alone did not certify
actual historical run end times.

Search mechanics are deliberately not claimed identical: only successful,
converged points can tighten a thermal bracket. A failed/nonconverged refinement
is indeterminate. Historical failures are preserved. The selected 2675-rpm point
and its successful 2650-rpm lower neighbour form the first real runtime check.
The 0.2-K/1% comparison tolerances are migration acceptance settings, not physics.

## Data provenance / numerical limitations

Frozen author exact and thermal results are not overwritten. New communication
and payload reference arithmetic was derived independently in Python during
Stage 1; its metadata now identifies traffic and normalization roles separately.
The new MATLAB entry points must be compared to those reference tables by the user.

There is no raw BurstGPT file and no supplied full-precision frozen tau table.
The tau display-only CSV is explicitly transcribed from the manuscript's rounded
percentages. It is not used as an upstream model input. The raw runner creates
full-precision values; it also recreates Fig.2a, which the fast route must skip.

Bootstrap daily aggregation preserves the estimator and sampled day indices, not
bitwise summation order. The new MC independent mode reuses archived lower anchors
instead of rerunning the historical coarse search, preserving the documented
refinement experiment rather than reintroducing obsolete manuscript N95 fields.

Old production MC scripts and backup-dependent recovery code are not on the
public MATLAB path. Excluding a file from this ZIP is not deletion from the
unchanged private source archive. Original legacy reference filenames are retained
inside their archive subfolders to preserve provenance.
