function out = export_upstream_supplementary_tables(varargin)
% EXPORT_UPSTREAM_SUPPLEMENTARY_TABLES SI Tables 1-8, preserving provenance.
% Table 2 uses the raw-derived tau table when supplied; otherwise its filename
% explicitly identifies the available manuscript-rounded display reference.
p0=haps_paths;p=inputParser;
addParameter(p,'WorkloadDir',p0.processed,@(x)ischar(x)||isstring(x));
addParameter(p,'ServingDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'ThermalDir',fullfile(p0.reference,'thermal'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'upstream_supplementary');
O=readtable(fullfile(o.WorkloadDir,'workload_occupancy.csv'),'TextType','string');
A=readtable(fullfile(o.WorkloadDir,'activity_statistics.csv'),'TextType','string');
[tf,i]=ismember(string(O.Type),string(A.Type));if ~all(tf),error('HAPS:Types','Missing activity types.');end
T=table(O.Type,O.RequestCount,100*O.ElapsedTimeShare_p_k,100*A.alpha_baseline(i), ...
    100*A.alpha_bootstrap_p025(i),100*A.alpha_bootstrap_p975(i),A.n_pairs_baseline(i), ...
    'VariableNames',{'Type','distance_count','pk_percent','alpha_percent','alpha_ci_low_percent','alpha_ci_high_percent','range_pairs'});
writetable(T,fullfile(outDir,'supp_table01_workload_statistics.csv'));
tauFile=fullfile(o.WorkloadDir,'tau_sensitivity.csv');
if isfile(tauFile)
    copyfile(tauFile,fullfile(outDir,'supp_table02_tau_sensitivity.csv'));
else
    copyfile(fullfile(p0.reference,'workload','tau_sensitivity_display_reference.csv'), ...
        fullfile(outDir,'supp_table02_tau_DISPLAY_ROUNDED.csv'));
end
copyfile(fullfile(o.ServingDir,'general_slo_capacity.csv'),fullfile(outDir,'supp_table03_general_slo.csv'));
T=readtable(fullfile(o.ServingDir,'nominal_interpolation_sensitivity.csv'),'TextType','string');
primary=["llama31_8b_1xH100_fp8_TP1","llama33_70b_2xH100_fp8_TP2"];
writetable(T(ismember(string(T.model_key),primary),:),fullfile(outDir,'supp_table04_nominal_interpolation.csv'));
A=readtable(fullfile(o.ThermalDir,'highload_a','A_summary.csv'),'TextType','string');
B=readtable(fullfile(o.ThermalDir,'highload_b','B_summary.csv'),'TextType','string');
C=readtable(fullfile(o.ThermalDir,'highload_c2','C2_summary.csv'),'TextType','string');
b=B(B.Q_server_W==1275&B.UA_ext_W_K==175,:);eligible=find(isfinite(C.fan_overhead_percent)&C.has_feasible_point==1);
[~,j]=min(C.fan_overhead_percent(eligible));c=C(eligible(j),:);
T=table(["Selected reference";"Fixed geometry";"Resized rejection";"Fixed geometry";"Best evaluated co-design"], ...
    [1100;1275;1275;2550;2550],[100;100;175;100;1000],[1;1;1;1;c.A1_scale], ...
    [1.5;1.5;1.5;1.5;c.duct_scale], ...
    [A.min_feasible_rpm(1:2);b.min_feasible_rpm;A.min_feasible_rpm(3);c.min_feasible_rpm], ...
    [A.min_fan_elec_power_W(1:2);b.min_fan_elec_power_W;A.min_fan_elec_power_W(3);c.min_fan_elec_power_W], ...
    'VariableNames',{'case_label','QIT_W','UA_ext_W_K','A1_scale','duct_scale','rpm','fan_electrical_power_W'});
T.fan_overhead_percent=100*T.fan_electrical_power_W./T.QIT_W;
writetable(T,fullfile(outDir,'supp_table05_highload_scaling.csv'));
% Supplementary Table 6 uses the manuscript-defined seven-row C2 envelope.
T6paper = build_supplementary_table6(o.ThermalDir);
writetable(T6paper,fullfile(outDir,'supp_table06_codesign_envelope.csv'));
copyfile(fullfile(o.ThermalDir,'robustness','thermal_fig4d_robustness_environment_corner.csv'), ...
    fullfile(outDir,'supp_table07_environment_corners.csv'));
copyfile(fullfile(o.ThermalDir,'robustness','thermal_fig4d_robustness_convergence_comparison.csv'), ...
    fullfile(outDir,'supp_table08_duration_comparison.csv'));
out=struct('output_dir',outDir);
end
