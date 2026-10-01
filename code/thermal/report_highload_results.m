function out = report_highload_results(summaryFile,outputDir)
% REPORT_HIGHLOAD_RESULTS Derive candidate/envelope tables from a final summary.
% No BACKUP/partial filename guessing and no new simulation. Empty selections
% keep the full column schema. Accepts migrated and source high-load summaries.
T=readtable(haps_require_file(summaryFile),'TextType','string');
outDir=haps_new_output_dir(outputDir,'highload_reporting');
if ismember('min_fan_elec_power_W',T.Properties.VariableNames)
    T.fan_electrical_power_W=T.min_fan_elec_power_W;
    T.threshold_resolved=haps_logical(T.has_feasible_point)&~haps_logical(T.left_censored);
end
valid=haps_logical(T.threshold_resolved)&isfinite(T.fan_overhead_percent)&isfinite(T.min_feasible_rpm);
allCandidates=sortrows(T(valid,:),{'fan_overhead_percent','min_feasible_rpm'});
preferred=allCandidates(allCandidates.min_feasible_rpm<=5000,:);
writetable(allCandidates,fullfile(outDir,'candidates_all.csv'));
writetable(preferred,fullfile(outDir,'candidates_preferred.csv'));
keys=unique([T.Q_server_W,T.UA_ext_W_K],'rows');best=T([],:);
for i=1:size(keys,1)
    t=allCandidates(allCandidates.Q_server_W==keys(i,1)&allCandidates.UA_ext_W_K==keys(i,2),:);
    if ~isempty(t),best=[best;t(1,:)];end %#ok<AGROW>
end
writetable(best,fullfile(outDir,'best_by_heat_load_and_ua.csv'));
out=struct('output_dir',outDir,'best_by_ua',best,'preferred',preferred);
end
