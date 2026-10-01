function out = validate_raw_workload_reproduction(varargin)
% VALIDATE_RAW_WORKLOAD_REPRODUCTION Fast raw BurstGPT regression (no bootstrap).
% Runs the public workload path with NumBootstrap=0 and checks that the main
% tau=1800 pair counts, p_k and alpha_k agree with the packaged full-precision
% reference outputs. Reference files are read only and never overwritten.

p0 = haps_paths;
p = inputParser;
addParameter(p,'BurstGPTFile','',@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'Tolerance',1e-12,@(x)isnumeric(x)&&isscalar(x)&&x>0);
parse(p,varargin{:});
o = p.Results;
if strlength(string(o.BurstGPTFile))==0
    error('HAPS:RawTraceRequired','Pass the local original BurstGPT CSV using BurstGPTFile.');
end

runOut = run_workload_analysis( ...
    'BurstGPTFile',o.BurstGPTFile, ...
    'OutputDir',o.OutputDir, ...
    'Tau',1800, ...
    'TauList',[600 1800 3600], ...
    'NumBootstrap',0, ...
    'Seed',1, ...
    'MakeFigures',false);

outDir = string(runOut.output_dir);
occ = readtable(fullfile(outDir,'workload_occupancy.csv'),'TextType','string');
act = readtable(fullfile(outDir,'activity_statistics.csv'),'TextType','string');
info = readtable(fullfile(outDir,'input_summary.csv'),'TextType','string');
refOcc = readtable(fullfile(p0.processed,'workload_occupancy.csv'),'TextType','string');
refAct = readtable(fullfile(p0.processed,'activity_statistics.csv'),'TextType','string');

checks = strings(0,1);
passed = false(0,1);
detail = strings(0,1);
add("missing_session_rows_detected",info.missing_session_after_cleaning>0, ...
    sprintf('%d unusable Session IDs after numeric cleaning.',info.missing_session_after_cleaning));
add("missing_session_policy_exclude",string(info.missing_session_policy)=="exclude", ...
    'Reference reproduction excludes requests without usable Session IDs.');
add("tau1800_pair_count",sum(occ.RequestCount)==127205, ...
    sprintf('Regenerated pair count = %d.',sum(occ.RequestCount)));
add("type_pair_counts",isequal(double(occ.RequestCount),double(refOcc.RequestCount)), ...
    'A-E pair counts match the packaged reference.');
add("pk_full_precision",max(abs(occ.ElapsedTimeShare_p_k-refOcc.ElapsedTimeShare_p_k))<=o.Tolerance, ...
    sprintf('max |delta p_k| = %.3g.',max(abs(occ.ElapsedTimeShare_p_k-refOcc.ElapsedTimeShare_p_k))));
add("alpha_full_precision",max(abs(act.alpha_baseline-refAct.alpha_baseline))<=o.Tolerance, ...
    sprintf('max |delta alpha_k| = %.3g.',max(abs(act.alpha_baseline-refAct.alpha_baseline))));
add("range_pair_counts",isequal(double(act.n_pairs_baseline),double(refAct.n_pairs_baseline)), ...
    'Range-mapped A-E pair counts match the packaged reference.');

report = table(checks,passed,detail,'VariableNames',{'check','passed','detail'});
writetable(report,fullfile(outDir,'raw_workload_regression_checks.csv'));
if ~all(report.passed)
    disp(report(~report.passed,:));
    error('HAPS:RawWorkloadRegression', ...
        'Raw workload reproduction did not match the packaged reference. Outputs were preserved.');
end
fprintf('PASS: raw BurstGPT baseline reproduces the packaged tau=1800 workload statistics.\n');
out = struct('passed',true,'output_dir',char(outDir),'checks',report,'input_summary',info);

    function add(name,value,msg)
        checks(end+1,1) = string(name);
        passed(end+1,1) = isscalar(value) && logical(value);
        detail(end+1,1) = string(msg);
    end
end
