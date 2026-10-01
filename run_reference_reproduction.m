function out = run_reference_reproduction(varargin)
% RUN_REFERENCE_REPRODUCTION Safe reference-based route, with no long sweep.
% Recomputes SLO/interpolation, communication and payload arithmetic. Exact
% thresholds and thermal results are READ from immutable reference CSVs.
% Raw BurstGPT, MC simulation, exact searches and Simscape are not run here.
setup_haps;
p=inputParser;
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'MakeFigures',true,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});opt=p.Results;paths=haps_paths;
outDir=haps_new_output_dir(opt.OutputDir,'reference_reproduction');
fprintf('Output directory: %s\n',outDir);
exactDir=fullfile(paths.reference,'exact');
serving=run_serving_analysis('OutputDir',fullfile(outDir,'serving'));
comm=run_communication_analysis('SingleInstanceFile',fullfile(exactDir,'single_instance_exact.csv'), ...
    'OutputDir',fullfile(outDir,'communication'),'Verbose',false);
payload=run_payload_analysis('SingleInstanceFile',fullfile(exactDir,'single_instance_exact.csv'), ...
    'AssignmentFile',fullfile(exactDir,'platform_assignment_exact.csv'), ...
    'RadioPowerFile',fullfile(comm.output_dir,'radio_power.csv'), ...
    'OutputDir',fullfile(outDir,'payload'));
record_environment(fullfile(outDir,'matlab_environment.csv'));
validation=validate_release('ExactDir',exactDir,'CommunicationDir',comm.output_dir, ...
    'PayloadDir',payload.output_dir,'CheckExactEngine',false);
writetable(validation,fullfile(outDir,'validation.csv'));
export_upstream_supplementary_tables('ServingDir',serving.output_dir, ...
    'OutputDir',fullfile(outDir,'supplementary_upstream'));
export_downstream_supplementary_tables('ExactDir',exactDir,'PayloadDir',payload.output_dir, ...
    'OutputDir',fullfile(outDir,'supplementary_downstream'));
if opt.MakeFigures
    plot_release_figures('ExactDir',exactDir,'CommunicationDir',comm.output_dir, ...
        'PayloadDir',payload.output_dir,'OutputDir',fullfile(outDir,'figures','downstream'));
    plot_workload_figures('OutputDir',fullfile(outDir,'figures','workload'));
    plot_serving_figures('ServingDir',serving.output_dir,'OutputDir',fullfile(outDir,'figures','serving'));
    plot_thermal_reference_figures('OutputDir',fullfile(outDir,'figures','thermal'));
end
out=struct('output_dir',outDir,'exact_source_dir',exactDir,'serving',serving, ...
    'communication',comm,'payload',payload,'validation',validation);
fprintf('Reference-based reproduction complete: %s\n',outDir);
end
