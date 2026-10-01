# Thermal execution boundaries

First: `run_thermal_smoke_test` (two actual5000-s simulations, 2650/2675 rpm).
Plan: `run_thermal_study('Study','duct')` (no model load or simulation).
Run: select a small `CaseIDs` set and pass `Execute=true` deliberately.

The 1158 entries include repeated references. The source25-rpm grid,5000-rpm
preferred limit,12000-rpm hard cap, temperature limits and sample-tail convergence
rules remain explicit. Failures and nonconvergence are not physical infeasibility.
Only a resolved adjacent bracket gets a minimum RPM. The new safe probe schedule
is not an assertion that every historical solver run was reproduced.

`report_highload_results(summaryFile,outputDir)` reads an explicit final summary
and preserves empty table schemas. It does not guess BACKUP or partial filenames.
See `docs/reproduction_guide.md` for check targets, tolerances and result bundling.
