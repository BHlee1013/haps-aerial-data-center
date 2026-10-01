function report = validate_release(varargin)
% VALIDATE_RELEASE Check numerical anchors and cross-file invariants.
% Default checks do not run a threshold sweep. CheckExactEngine=true evaluates
% the four primary boundary probabilities with the migrated MATLAB engine.
% A returned table means the assertions ran in THIS MATLAB session. The shipped
% Python audit is independent arithmetic validation, not a MATLAB run.
p0=haps_paths;p=inputParser;
addParameter(p,'ExactDir',fullfile(p0.reference,'exact'),@(x)ischar(x)||isstring(x));
addParameter(p,'CommunicationDir',fullfile(p0.reference,'communication'),@(x)ischar(x)||isstring(x));
addParameter(p,'PayloadDir',fullfile(p0.reference,'payload'),@(x)ischar(x)||isstring(x));
addParameter(p,'CheckExactEngine',false,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});o=p.Results;
checks=cell(0,3);
S=readtable(haps_require_file(fullfile(o.ExactDir,'single_instance_exact.csv')),'TextType','string');
A=readtable(haps_require_file(fullfile(o.ExactDir,'platform_assignment_exact.csv')),'TextType','string');
F=readtable(haps_require_file(fullfile(o.ExactDir,'fleet_sizing_exact.csv')),'TextType','string');
Q=readtable(haps_require_file(fullfile(o.ExactDir,'activity_quantiles_exact.csv')),'TextType','string');
D=readtable(haps_require_file(fullfile(o.CommunicationDir,'downlink_rates.csv')),'TextType','string');
L=readtable(haps_require_file(fullfile(o.CommunicationDir,'link_budget.csv')),'TextType','string');
C=readtable(haps_require_file(fullfile(o.CommunicationDir,'radio_power.csv')),'TextType','string');
B=readtable(haps_require_file(fullfile(o.CommunicationDir,'auxiliary_parity.csv')),'TextType','string');
P=readtable(haps_require_file(fullfile(o.PayloadDir,'deployment_limits.csv')),'TextType','string');
keys=["llama31_8b_1xH100_fp8_TP1";"llama31_8b_1xH200_fp8_TP1"; ...
    "llama31_8b_1xL40S_fp8_TP1";"llama33_70b_2xH100_fp8_TP2"; ...
    "llama33_70b_2xH200_fp8_TP2";"llama33_70b_4xH100_fp8_TP4"];
[tf,idx]=ismember(keys,string(S.model_key));
check(all(tf),'single_configurations','Six feasible exact configurations found');
expected=[5876;7245;1337;991;936;2784];
check(isequal(double(S.N95_exact(idx)),expected),'single_thresholds','Current exact N95 values');
check(all(S.P_at_N95(idx)<=0.05 & S.P_at_N95_plus_1(idx)>0.05),'single_crossings','Adjacent exact threshold crossing');
check(all(abs(S.N95_exact(idx)./S.IT_power_kW(idx)-S.serving_efficiency_user_eq_per_kW(idx))<1e-8), ...
    'serving_efficiency','Exact N95 divided by IT power');
[~,alpha,q]=localWorkload();
alloc=haps_allocation(max(expected)+1,q);
for j=1:numel(idx)
    n=double(S.N95_exact(idx(j)));
    nk=double(S{idx(j),{'N_A','N_B','N_C','N_D','N_E'}});
    check(isequal(nk,alloc(n,:)),sprintf('population_%d',j),'Sequential-deficit allocation agrees');
end
primary=[keys(1);keys(4)];expectedP=[174;34];expected99=[183;38];
for j=1:2
    rows=string(D.model_key)==primary(j);qrow=string(Q.model_key)==primary(j);
    check(sum(rows)==2&&sum(qrow)==1,sprintf('traffic_rows_%d',j),'Two byte/token endpoints');
    check(all(D.p95_active_users(rows)==expectedP(j)&D.p99_active_users(rows)==expected99(j)), ...
        sprintf('traffic_quantiles_%d',j),'Current exact-population quantiles');
    check(all(abs(D.mean_active_users(rows)-Q.mean_active(qrow))<1e-8), ...
        sprintf('traffic_mean_%d',j),'PMF mean agrees with exact activity reference');
end
check(all(abs(D.design_rate_p95_Mbps-8*3*D.bytes_per_token.*D.p95_active_users/(100*1000))<1e-12), ...
    'traffic_conversion','100-ms ITL with protocol factor three');
check(all(abs(C.P_comm_W-(C.PA_DC_dynamic_total_W+C.fixed_RF_BB_before_DCDC_W_total)./(1-C.DCDC_loss_fraction))<1e-9), ...
    'radio_power','No double multiplication of total PA power');
check(all(abs(B.break_even_ground_cooling_percent-100*(B.fan_power_W+B.communication_power_W)./B.IT_power_W)<1e-10), ...
    'auxiliary_parity','Fan plus radio divided by IT');
check(all(B.IT_power_W==1275),'parity_reference','Final 1.275-kW normalization');
check(all(abs(B.fan_power_W-10.0081045947057)<1e-10),'scaled_fan','Stored thermal module ratio scaled to 1.275 kW');
floorMask=string(L.link_scenario)=="snr_floor_0dB"&string(L.rate_stat)=="p95"&L.slant_distance_km==60;
check(all(abs(L.payload_bearing_radiated_Tx_W(floorMask)-0.637046024671918)<1e-10), ...
    'radiated_floor','60-km 0-dB receiver-floor stress result');
check(all(F.minimum_active_HAPS_count==ceil(F.target_user_equivalents./F.best_exact_NHAPS95)), ...
    'fleet_ceiling','Compute-dimensioning ceiling rule');
check(all(A.linear_mN95_exact==A.m_instances.*A.single_N95_exact),'linear_reference','Linear reference is not pooled capacity');
check(all(A.P_pooled_at_NHAPS95<=.05 & A.P_pooled_at_NHAPS95_plus_1>.05), ...
    'pooled_crossings','Exact pooled adjacent crossings');
check(all(A.P_static_at_NHAPS95<=.05 & A.P_static_at_NHAPS95_plus_1>.05), ...
    'static_crossings','Exact static adjacent crossings');
mask=string(P.platform)=="Stratobus"&string(P.model_key)=="llama31_8b_1xL40S_fp8_TP1";
check(sum(mask)==1&&P.deployable_instances(mask)==10&&string(P.binding_constraint(mask))=="server_gpu_cap", ...
    'l40s_binding','Uncapped resource bounds kept separate from the 10-GPU cap');
check(sum(P.deployable_instances>0)==8,'deployment_count','Eight feasible platform/configuration rows');
for i=1:height(A)
    hit=string(P.platform)==string(A.platform(i))&string(P.model_key)==string(A.model_key(i));
    check(sum(hit)==1&&P.deployable_instances(hit)==A.m_instances(i), ...
        sprintf('deployment_%d',i),'Payload count agrees with exact assignment calculation');
end
if o.CheckExactEngine
    for j=[1,4]
        i=idx(j);n=double(S.N95_exact(i));cm=double(S{i,{'Cmax_A','Cmax_B','Cmax_C','Cmax_D','Cmax_E'}}).';
        v=exact_binomial_overload_probability(alloc(n,:).',alpha,cm);
        vp=exact_binomial_overload_probability(alloc(n+1,:).',alpha,cm);
        check(abs(v-S.P_at_N95(i))<1e-8&&abs(vp-S.P_at_N95_plus_1(i))<1e-8, ...
            sprintf('engine_boundary_%d',j),'Migrated exact probability engine evaluated in MATLAB');
    end
end
report=cell2table(checks,'VariableNames',{'check','passed','detail'});
fprintf('Passed %d MATLAB release checks.\n',height(report));
    function check(tf,name,detail)
        if ~isscalar(tf)||~tf,error('HAPS:ValidationFailed','%s: %s',name,detail);end
        checks(end+1,:)={string(name),true,string(detail)};
    end
    function [p,a,q0]=localWorkload()
        [p,a]=load_workload_inputs;
        q0=p./a;q0=q0/sum(q0);
    end
end
