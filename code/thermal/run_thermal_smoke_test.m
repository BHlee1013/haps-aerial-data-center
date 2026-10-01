function out = run_thermal_smoke_test(varargin)
% RUN_THERMAL_SMOKE_TEST Replay selected reference and its 25-rpm lower point.
% This runs TWO actual 5000-s simulations by default, not a complete sweep.
% StopTimeSeconds<5000 is a compilation/connectivity test only and NEVER a
% successful reproduction claim. Traces and partial failure records are kept.
p0=haps_paths;p=inputParser;
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'StopTimeSeconds',5000,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'SaveTimeseries',true,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'thermal_smoke');
C=load_thermal_cases('robustness','robustness_0001');C.stop_time_s=o.StopTimeSeconds;
writetable(C,fullfile(outDir,'case_parameters.csv'));record_environment(fullfile(outDir,'matlab_environment.csv'));
target=readtable(fullfile(p0.processed,'thermal_smoke_checkpoints.csv'),'TextType','string');
record_repository_snapshot(fullfile(outDir,'repository_snapshot.csv'));
try
    cleanup=thermal_model_session(C,outDir); %#ok<NASGU>
catch ME
    fid=fopen(fullfile(outDir,'error_report.txt'),'w');
    if fid>=0,fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off'));fclose(fid);end
    fprintf('Model loading failed; inputs and error retained in %s\n',outDir);rethrow(ME);
end

rows=cell(height(target),1);
for i=1:height(target)
    traceDir='';if o.SaveTimeseries,traceDir=fullfile(outDir,sprintf('trace_%d_rpm',target.rpm(i)));end
    rows{i}=run_thermal_point(C,target.rpm(i),'smoke',traceDir);
    partial=struct2table(vertcat(rows{1:i}));writetable(partial,fullfile(outDir,'point_results.csv'));
end
results=struct2table(vertcat(rows{:}));
comparison=target;comparison.sim_success=results.sim_success;comparison.actual_feasible=results.feasible;
comparison.power_relative_error=abs(results.fan_electrical_power_W-target.fan_electrical_power_W)./target.fan_electrical_power_W;
comparison.server_error_K=results.server_mean_tail_K-target.server_mean_tail_K;
comparison.chamber_error_K=results.chamber_mean_tail_K-target.chamber_mean_tail_K;
comparison.reproduction_eligible=repmat(o.StopTimeSeconds==5000,height(target),1);
comparison.passed=results.sim_success&results.converged& ...
    results.feasible==logical(target.expected_feasible)&comparison.power_relative_error<.01& ...
    abs(comparison.server_error_K)<.2&abs(comparison.chamber_error_K)<.2&comparison.reproduction_eligible;
writetable(comparison,fullfile(outDir,'comparison.csv'));
out=struct('output_dir',outDir,'results',results,'comparison',comparison, ...
    'reproduction_passed',all(comparison.passed));
if out.reproduction_passed
    fprintf('Thermal boundary reproduction passed: %s\n',outDir);
else
    warning('HAPS:ThermalSmokeNotPassed','Not certified as a reference reproduction. Inspect comparison.csv and point_results.csv in %s.',outDir);
end
end
