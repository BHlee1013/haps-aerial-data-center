function out = run_stage2_validation(varargin)
% RUN_STAGE2_VALIDATION First user-side acceptance test for the integrated ZIP.
% No raw trace, expensive exact search, MC sampling, or Simscape run occurs.
% Run once with MakeFigures=false, then again with true in a separate folder.
setup_haps;p=inputParser;
addParameter(p,'MakeFigures',false,@(x)islogical(x)&&isscalar(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'stage2_validation');fprintf('Validation directory: %s\n',outDir);
try
    record_repository_snapshot(fullfile(outDir,'repository_snapshot.csv'));
    issues=check_matlab_code;writetable(issues,fullfile(outDir,'code_analyzer.csv'));
    extra=validate_stage2('OutputFile',fullfile(outDir,'stage2_checks.csv'));
    numerical=run_reference_reproduction('MakeFigures',o.MakeFigures,'OutputDir',fullfile(outDir,'reproduction'));
    allPassed=all(extra.passed)&&all(numerical.validation.passed)&&all(numerical.serving.comparison.passed);
    summary=table(allPassed,o.MakeFigures,height(issues),height(extra),height(numerical.validation), ...
        height(numerical.serving.comparison),false,false,false, ...
        'VariableNames',{'passed','figures_requested','analyzer_messages','stage2_checks', ...
        'release_checks','serving_comparisons','thermal_simulated','monte_carlo_run','raw_trace_processed'});
    writetable(summary,fullfile(outDir,'acceptance_summary.csv'));
    out=struct('output_dir',outDir,'passed',allPassed,'summary',summary,'reproduction',numerical);
    fprintf('Stage-2 reference acceptance passed=%d. Analyzer messages are recorded separately.\n',allPassed);
catch ME
    fid=fopen(fullfile(outDir,'error_report.txt'),'w');
    if fid>=0,fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off'));fclose(fid);end
    fprintf('Validation stopped; partial outputs preserved in %s\n',outDir);rethrow(ME);
end
end
