# Simscape model snapshots

`haps_thermal_reference.slx` is the renamed, byte-identical E1/reference model.
The supplied high-load source SLX has the same hash and is deduplicated.
`haps_thermal_map.slx` is the distinct E2 map model. `model_manifest.csv` records
both SHA-256 identities. Blocks, connections and solver settings were not edited
in this release-candidate update.

The author successfully ran the reference model at 2650 and 2675 rpm for 5000 s
of model time each using the migrated runner in MATLAB/Simscape R2025b. Evidence
and actual traces are under `docs/validation_evidence/r2025b_20260930/`.
The map model is hash-verified, but this bundle does not contain a new map-model
simulation or a new full sweep. These statements are deliberately distinct.

Use `run_thermal_smoke_test` or an explicit `run_thermal_study` call rather than
opening a model expecting an old base workspace. No physical parameters are
inferred from file names; unified cases carry absolute inputs. Nothing in the
release-integrity verifier starts a model. Preserve these source bytes before
performing any later physics/model edits.
