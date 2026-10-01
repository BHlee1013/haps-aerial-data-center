function out = export_downstream_supplementary_tables(varargin)
% EXPORT_DOWNSTREAM_SUPPLEMENTARY_TABLES Emit numerical sources for SI Tables 9-15.
% Table 15 uses separate fully bracketed independent-seed diagnostics for its
% mean/median/std/range. Narrow-range pooled per-seed tables are NOT substituted.
paths=haps_paths;p=inputParser;
addParameter(p,'ExactDir',fullfile(paths.reference,'exact'),@(x)ischar(x)||isstring(x));
addParameter(p,'PayloadDir',fullfile(paths.reference,'payload'),@(x)ischar(x)||isstring(x));
addParameter(p,'MappingAlphaFile',fullfile(paths.processed,'mapping_activity.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'MappingFile',fullfile(paths.reference,'mapping','mapping_sensitivity_exact.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'ValidationDir',fullfile(paths.reference,'validation'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'supplementary_tables');
Q=readcsv(fullfile(o.ExactDir,'activity_quantiles_exact.csv'));
H=readcsv(fullfile(o.PayloadDir,'configuration_efficiency.csv'));
A=readcsv(fullfile(o.ExactDir,'platform_assignment_exact.csv'));
M=readcsv(o.MappingFile);
T13=readcsv(o.MappingAlphaFile);
seed=readcsv(fullfile(o.ValidationDir,'independent_seed_diagnostic_per_seed.csv'));
writetable(Q,fullfile(outDir,'table09_activity_and_downlink.csv'));
writetable(H,fullfile(outDir,'table10_hardware_and_exact_capacity.csv'));
writetable(A(:,{'platform','model_key','display_label','m_instances','linear_mN95_exact', ...
    'NHAPS95_pooled_exact','pooled_gain_vs_linear_percent'}),fullfile(outDir,'table11_pooled_capacity.csv'));
writetable(A(A.m_instances>1,{'platform','model_key','display_label','m_instances', ...
    'NHAPS95_static_exact','linear_mN95_exact','NHAPS95_pooled_exact','P_static_at_linear_mN95'}), ...
    fullfile(outDir,'table12_assignment_sensitivity.csv'));
writetable(T13,fullfile(outDir,'table13_mapping_activity.csv'));
writetable(M,fullfile(outDir,'table14_exact_mapping_sensitivity.csv'));
rows=cell(2,9);family=["8b","70b"];
for i=1:2
    pooled=readcsv(fullfile(o.ValidationDir,char(family(i)+"_pooled_mc_summary.csv")));
    if height(pooled)~=1,error('HAPS:MCRegistry','Require one pooled-MC summary row.');end
    sub=seed(string(seed.model_key)==string(pooled.model_key(1)),:);
    if height(sub)~=20 || any(haps_logical(sub.left_censored)|haps_logical(sub.right_censored)) || any(~isfinite(sub.N95))
        error('HAPS:MCBracketing','Require 20 uncensored finite independent-seed thresholds.');
    end
    x=double(sub.N95);
    rows(i,:)={string(pooled.model_key(1)),double(pooled.exact_reference_N95(1)), ...
        double(pooled.N95_pooled_MC(1)),double(pooled.N95_pooled_MC(1)-pooled.exact_reference_N95(1)), ...
        mean(x),median(x),std(x,0),min(x),max(x)};
end
T15=cell2table(rows,'VariableNames',{'model_key','N95_exact','N95_pooled_MC', ...
    'MC_minus_exact','independent_seed_mean','independent_seed_median', ...
    'independent_seed_sample_std','independent_seed_min','independent_seed_max'});
writetable(T15,fullfile(outDir,'table15_mc_validation.csv'));
out=struct('output_dir',outDir,'mc_validation',T15);
end
function T=readcsv(f)
T=readtable(haps_require_file(f),'TextType','string');
end
