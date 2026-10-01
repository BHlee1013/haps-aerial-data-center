# Stage-1 changes from the supplied research files

## Exact reliability and mapping

The probability, strict-tail and sequential-deficit algorithms were retained. Public function names are stable English names. Inputs now resolve relative to the repository, and missing explicit inputs produce errors instead of wildcard substitution. Core population arguments reject nonintegers rather than silently rounding them.

The old `old_reported_N95`, `old_pooled_NHAPS95`, `old_static_NHAPS95` and mapping `old_*` search guesses were removed from production registries. Search brackets now initialize from the same nominal model quantities already supported by the supplied solvers. The dedicated mapping runner reads `mapping_activity.csv` at full precision; the older rounded template is not a default or fallback.

## Communication

The supplied radio/link numerical routines were retained. The legacy Fig3e/registered-mix input interface was replaced by an explicit adapter from `single_instance_exact.csv` plus the reviewed full-precision workload inputs. Type populations are validated against the adopted monotonic allocation, not freshly rounded by a different rule.

Consequently, 70B uses N95=991, mean active users about 26.006, P50=26, P95=34 and P99=38. The PMF, input audit, all-active comparison and non-P95 rows were regenerated rather than relabelling a 962-population output. P95-based link/radio values are unchanged where the P95 count is unchanged.

Parity uses 1275 W IT and the original thermal module fan/IT ratio, giving about 10.0081046 W fan power. No old 1100-W parity table is silently used as the current normalization. Radio source model and IT normalization retain their distinct meanings.

## Payload

Configuration efficiency uses current exact N95. The engineering power/mass models are unchanged. Full-precision engineering masses used by the Fig. 6b/c model are preserved separately from the slightly rounded masses in the original exact hardware registry; those two conventions are not silently conflated.

Uncapped mass/power arithmetic limits are retained before the 10-GPU L40S host cap is applied. The Stratobus L40S binding label is therefore `server_gpu_cap`, not the previous spurious mass+power+cap tie. Above-cap affine limits are diagnostics, not proposed supported hardware configurations.

Linear, pooled and static values have distinct fields. The old `N95_if_independent_instances` interpretation is not retained as a reliability guarantee.

## Plotting and supplementary

The unified numerical plotter reads exact/population-consistent outputs directly. It has no Monte-Carlo production branch and no answer-generating hardcoded capacity table. Source CSVs are exported for each panel; composition/typography may differ from the manually assembled manuscript figures. SI Table 15 uses the fully bracketed independent-seed data, not narrow-range pooled per-seed NaNs.

## Safety and reproducibility

New outputs use new directories. Original/reviewed input files are not overwritten. No raw trace, credentials, private paper PDFs or font files are included. Author-approved licensing and final archive metadata remain release gates.
