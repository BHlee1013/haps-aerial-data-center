function out = run_full_reproduction(varargin)
% RUN_FULL_REPRODUCTION Recompute deterministic analytical stages, not all tasks.
% Uses frozen workload inputs unless WorkloadDir supplies a regenerated set.
% No Simscape/MC/raw-trace job is started implicitly. Pooled exact searches
% may be expensive. Begin with run_stage2_validation instead.
setup_haps;
p=inputParser;
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'MakeFigures',true,@(x)islogical(x)&&isscalar(x));
addParameter(p,'WorkloadDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'ComputeMapping',true,@(x)islogical(x)&&isscalar(x));
addParameter(p,'Verbose',true,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});opt=p.Results;
outDir=haps_new_output_dir(opt.OutputDir,'analytical_full');
paths=haps_paths;wdir=char(opt.WorkloadDir);if isempty(wdir),wdir=paths.processed;end
% WorkloadDir must reproduce the paper inputs to pass validate_release below.
shareFile=fullfile(wdir,'workload_occupancy.csv');alphaFile=fullfile(wdir,'activity_statistics.csv');
serving=run_serving_analysis('WorkloadShareFile',shareFile,'AlphaFile',alphaFile, ...
    'OutputDir',fullfile(outDir,'serving'));
exact=run_exact_analysis('WorkloadShareFile',shareFile,'AlphaFile',alphaFile, ...
    'OutputDir',fullfile(outDir,'exact'),'Verbose',opt.Verbose);
if opt.ComputeMapping
    mapping=run_mapping_sensitivity('WorkloadShareFile',shareFile, ...
        'MappingAlphaFile',fullfile(wdir,'mapping_activity.csv'),'CmaxRegistryFile',fullfile(exact.output_dir,'general_slo_capacity.csv'), ...
        'OutputDir',fullfile(outDir,'mapping'),'Verbose',opt.Verbose);
    mapFile=mapping.output_file;
else
    mapping=[];paths=haps_paths;
    mapFile=fullfile(paths.reference,'mapping','mapping_sensitivity_exact.csv');
end
comm=run_communication_analysis('PkFile',shareFile,'AlphaFile',alphaFile,'SingleInstanceFile',fullfile(exact.output_dir,'single_instance_exact.csv'), ...
    'OutputDir',fullfile(outDir,'communication'),'Verbose',opt.Verbose);
payload=run_payload_analysis('SingleInstanceFile',fullfile(exact.output_dir,'single_instance_exact.csv'), ...
    'AssignmentFile',fullfile(exact.output_dir,'platform_assignment_exact.csv'), ...
    'RadioPowerFile',fullfile(comm.output_dir,'radio_power.csv'),'OutputDir',fullfile(outDir,'payload'));
record_environment(fullfile(outDir,'matlab_environment.csv'));
validation=validate_release('ExactDir',exact.output_dir,'CommunicationDir',comm.output_dir, ...
    'PayloadDir',payload.output_dir,'CheckExactEngine',false);
writetable(validation,fullfile(outDir,'validation.csv'));
export_upstream_supplementary_tables('WorkloadDir',wdir,'ServingDir',serving.output_dir, ...
    'OutputDir',fullfile(outDir,'supplementary_upstream'));
export_downstream_supplementary_tables('ExactDir',exact.output_dir,'PayloadDir',payload.output_dir, ...
    'MappingFile',mapFile,'MappingAlphaFile',fullfile(wdir,'mapping_activity.csv'), ...
    'OutputDir',fullfile(outDir,'supplementary_downstream'));
if opt.MakeFigures
    plot_release_figures('ExactDir',exact.output_dir,'MappingFile',mapFile, ...
        'MappingAlphaFile',fullfile(wdir,'mapping_activity.csv'), ...
        'CommunicationDir',comm.output_dir,'PayloadDir',payload.output_dir, ...
        'OutputDir',fullfile(outDir,'figures','downstream'));
    plot_workload_figures('WorkloadDir',wdir,'OutputDir',fullfile(outDir,'figures','workload'));
    plot_serving_figures('ServingDir',serving.output_dir,'OutputDir',fullfile(outDir,'figures','serving'));
    plot_thermal_reference_figures('OutputDir',fullfile(outDir,'figures','thermal'));
end
out=struct('output_dir',outDir,'serving',serving,'exact',exact,'mapping',mapping, ...
    'communication',comm,'payload',payload,'validation',validation);
fprintf('Deterministic analytical recomputation complete: %s\n',outDir);
end
