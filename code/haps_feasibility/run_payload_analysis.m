function out = run_payload_analysis(varargin)
% RUN_PAYLOAD_ANALYSIS Integrate exact capacity with payload power and mass.
% Uses the existing engineering allocations and L40S shared-host equations.
% Radio reserve is charged once per HAPS; fan power scales with aggregate IT.
% Raw resource bounds are not clipped before identifying the binding limit.
% Linear m*N95 is a comparison only, never a pooled/static reliability result.
paths=haps_paths;
p=inputParser;
addParameter(p,'SingleInstanceFile',fullfile(paths.reference,'exact','single_instance_exact.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'AssignmentFile',fullfile(paths.reference,'exact','platform_assignment_exact.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'RadioPowerFile',fullfile(paths.reference,'communication','radio_power.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'MassFile',fullfile(paths.processed,'engineering_mass_allocations.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'PlatformFile',fullfile(paths.processed,'platform_envelopes.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'ThermalReferenceFile',fullfile(paths.processed,'thermal_reference.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'SharedHostFile',fullfile(paths.processed,'shared_host_parameters.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'payload');
S=readtable(haps_require_file(o.SingleInstanceFile),'TextType','string');
A=readtable(haps_require_file(o.AssignmentFile),'TextType','string');
C=readtable(haps_require_file(o.RadioPowerFile),'TextType','string');
M=readtable(haps_require_file(o.MassFile),'TextType','string');
P=readtable(haps_require_file(o.PlatformFile),'TextType','string');
T=readtable(haps_require_file(o.ThermalReferenceFile),'TextType','string');
H=readtable(haps_require_file(o.SharedHostFile),'TextType','string');
if height(T)~=1||height(H)~=1, error('HAPS:ParameterRows','Require one thermal and shared-host parameter row.'); end
feasible=haps_logical(S.SLO_feasible);
[tf,idx]=ismember(string(S.model_key),string(M.model_key));
if ~all(tf)||numel(unique(M.model_key))~=height(M)
    error('HAPS:MassRegistry','Require one engineering mass row per configuration.');
end
mass=double(M.engineering_mass_kg(idx));
fanRatio=double(T.fan_electrical_power_W(1))/double(T.reference_IT_power_W(1));
% This matches the supplied platform reference; preserve the full model source.
mask=string(C.model_key)=="llama33_70b_2xH100_fp8_TP2" & ...
    string(C.rate_stat)=="p95" & C.bytes_per_token==6 & C.slant_distance_km==20 & ...
    string(C.link_scenario)=="snr_floor_0dB" & string(C.circuit_scenario)=="bb_linear_scaled" & ...
    string(C.earth_bs_type)=="Pico" & C.analysis_NTRX==1;
if sum(mask)~=1, error('HAPS:RadioReference','Require exactly one selected one-chain Pico reference.'); end
radioW=double(C.P_comm_W(mask));
validateattributes(radioW,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(fanRatio,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(mass,{'numeric'},{'finite','positive'});
validateattributes(S.IT_power_kW,{'numeric'},{'finite','positive'});
config=table(string(S.model_key),string(S.display_label),feasible,double(S.IT_power_kW), ...
    mass,double(S.allocated_mass_kg),double(S.N95_exact), ...
    double(S.N95_exact)./double(S.IT_power_kW),double(S.Cmix),double(S.Nharm), ...
    double(S.N95_exact)./double(S.Nharm), ...
    'VariableNames',{'model_key','display_label','SLO_feasible','IT_power_kW', ...
    'engineering_mass_kg','exact_registry_mass_kg','N95_exact', ...
    'serving_efficiency_user_eq_per_kW','Cmix','Nharm','N95_over_Nharm'});
rows=cell(height(P)*height(S),19);r=0;
for ip=1:height(P)
    massLimit=double(P.payload_mass_limit_kg(ip));
    powerLimit=1000*double(P.payload_power_limit_kW(ip));
    for i=1:height(S)
        isL40S=string(S.model_key(i))==string(H.model_key(1));
        if isL40S
            fixedMass=double(H.host_mass_kg); unitMass=double(H.gpu_mass_kg);
            fixedW=1000*double(H.host_power_kW); unitW=1000*double(H.gpu_power_kW);
            cap=double(H.max_gpu_count);
        else
            fixedMass=0; unitMass=mass(i); fixedW=0;unitW=1000*double(S.IT_power_kW(i));cap=Inf;
        end
        rawMass=max(0,floor((massLimit-fixedMass)/unitMass));
        rawIT=max(0,floor((powerLimit-fixedW)/unitW));
        rawAux=max(0,floor(((powerLimit-radioW)/(1+fanRatio)-fixedW)/unitW));
        itOnly=min([rawMass,rawIT,cap]); actual=min([rawMass,rawAux,cap]);
        if ~feasible(i)
            actual=0;itOnly=0;binding="slo_infeasible";
        else
            names=["mass","power","server_gpu_cap"];
            limits=[rawMass,rawAux,cap];
            binding=strjoin(names(limits==min(limits)),"+");
        end
        if actual>0
            itW=fixedW+actual*unitW; mTotal=fixedMass+actual*unitMass;
            fanW=itW*fanRatio; totalW=itW+fanW+radioW;
            linear=actual*double(S.N95_exact(i));
            hit=string(A.platform)==string(P.platform_name(ip)) & string(A.model_key)==string(S.model_key(i));
            if sum(hit)~=1 || double(A.m_instances(hit))~=actual || ~haps_logical(A.feasible(hit))
                error('HAPS:DeploymentMismatch','Payload counts and exact assignment input disagree; recompute exact assignment.');
            end
            pooled=double(A.NHAPS95_pooled_exact(hit));stat=double(A.NHAPS95_static_exact(hit));
        else
            itW=0;mTotal=0;fanW=0;totalW=0;linear=NaN;pooled=NaN;stat=NaN;
        end
        r=r+1;
        rows(r,:)={string(P.platform_name(ip)),string(S.model_key(i)),string(S.display_label(i)), ...
            feasible(i),rawMass,rawIT,rawAux,cap,itOnly,actual,binding,mTotal,itW,fanW,radioW,totalW,linear,pooled,stat};
    end
end
deploy=cell2table(rows,'VariableNames',{'platform','model_key','display_label','SLO_feasible', ...
    'uncapped_mass_bound','uncapped_IT_power_bound','uncapped_aux_power_bound','host_gpu_cap', ...
    'IT_only_instances','deployable_instances','binding_constraint','deployed_mass_kg', ...
    'deployed_IT_power_W','deployed_fan_power_W','radio_reserve_W','total_payload_power_W', ...
    'linear_mN95_reference','NHAPS95_pooled_exact','NHAPS95_static_exact'});
% Above-cap affine limits are algebraic diagnostics, not validated host designs.
n=(1:double(H.max_gpu_count)).';
li=find(string(S.model_key)==string(H.model_key(1)));
if numel(li)~=1,error('HAPS:SharedHost','L40S single-instance row is not unique.');end
host=table(n,double(H.host_mass_kg)+n*double(H.gpu_mass_kg), ...
    double(H.host_power_kW)+n*double(H.gpu_power_kW),n*double(S.N95_exact(li)), ...
    'VariableNames',{'gpu_count','engineering_mass_kg','IT_power_kW','linear_mN95_reference'});
writetable(config,fullfile(outDir,'configuration_efficiency.csv'));
writetable(deploy,fullfile(outDir,'deployment_limits.csv'));
writetable(host,fullfile(outDir,'shared_host_scaling.csv'));
out=struct('configuration',config,'deployments',deploy,'shared_host',host, ...
    'radio_reserve_W',radioW,'fan_to_IT_ratio',fanRatio,'output_dir',outDir);
end
