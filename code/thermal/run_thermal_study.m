function out = run_thermal_study(varargin)
% RUN_THERMAL_STUDY Explicitly gated replay of the archived thermal designs.
% Default Execute=false only lists cases (does not load Simulink or run sim).
% Studies: map (957), duct (14), robustness (22), highload_a (3), highload_b
% (18), highload_c (60), highload_c2 (84). Counts include reference repeats.
% Select CaseIDs for bounded batches. Every invocation uses a NEW folder.
p=inputParser;
addParameter(p,'Study','duct',@(x)ismember(string(x),["map","duct","robustness","highload_a","highload_b","highload_c","highload_c2"]));
addParameter(p,'CaseIDs',strings(0,1),@(x)isstring(x)||iscellstr(x)||ischar(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'Execute',false,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});o=p.Results;C=load_thermal_cases(o.Study,o.CaseIDs);
if ~o.Execute
    disp(C(:,{'case_id','Q_server','A2','G_wall','A1','duct_area_scale','stop_time_s'}));
    fprintf('%d cases planned. No simulation run. Pass Execute=true to proceed.\n',height(C));
    out=struct('executed',false,'cases',C,'output_dir','');return;
end
outDir=haps_new_output_dir(o.OutputDir,['thermal_' char(o.Study)]);
writetable(C,fullfile(outDir,'case_parameters.csv'));record_environment(fullfile(outDir,'matlab_environment.csv'));
record_repository_snapshot(fullfile(outDir,'repository_snapshot.csv'));
try
    cleanup=thermal_model_session(C,outDir); %#ok<NASGU>
catch ME
    fid=fopen(fullfile(outDir,'error_report.txt'),'w');
    if fid>=0,fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off'));fclose(fid);end
    fprintf('Model loading failed; inputs and error retained in %s\n',outDir);rethrow(ME);
end
parts=cell(height(C),1);
for i=1:height(C)
    caseDir=fullfile(outDir,char(C.case_id(i)));mkdir(caseDir);
    [~,summary]=search_thermal_speed(C(i,:),caseDir);parts{i}=summary;
    writetable(summary,fullfile(caseDir,'summary.csv'));
    writetable(vertcat(parts{1:i}),fullfile(outDir,'summary.csv'));
end
summary=vertcat(parts{:});
if startsWith(string(o.Study),"highload"),report_highload_results(fullfile(outDir,'summary.csv'),fullfile(outDir,'reporting'));end
out=struct('executed',true,'output_dir',outDir,'summary',summary);
fprintf('Thermal study complete: %s\n',outDir);
end
