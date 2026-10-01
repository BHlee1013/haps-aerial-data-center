function out = run_exact_analysis(varargin)
% RUN_EXACT_ANALYSIS Recompute single, pooled and static Binomial thresholds.
% This is the migrated deterministic engine, not Monte-Carlo estimation.
% Defaults use repository-relative processed inputs. The full-precision
% activity-mapping sensitivity is run separately by run_mapping_sensitivity.
% Every output directory must be new and outside packaged reference data.
% This calculation can be expensive, especially pooled L40S; use the
% reference reproduction command for a fast data-to-figure route.
paths=haps_paths;
%% Options
p=inputParser;
addParameter(p,'WorkloadShareFile',fullfile(paths.processed,'workload_occupancy.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'AlphaFile',fullfile(paths.processed,'activity_statistics.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'NIMBenchmarkFile',fullfile(paths.processed,'nim_benchmark.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'HardwareRegistryFile',fullfile(paths.processed,'hardware_registry.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'PlatformDeploymentsFile',fullfile(paths.processed,'platform_deployments.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'ReliabilityThreshold',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);
addParameter(p,'ComputePrimaryCurves',true,@(x)islogical(x)||isnumeric(x));
addParameter(p,'PrimaryCurveRatios',0.40:0.05:1.05,@isnumeric);
addParameter(p,'Verbose',true,@(x)islogical(x)||isnumeric(x));
addParameter(p,'TargetDemands',[10000 25000 50000 100000],@isnumeric);
addParameter(p,'TrafficITLms',100,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'TrafficBytesPerToken',[4 6],@isnumeric);
addParameter(p,'TrafficOverheadFactor',3,@(x)isnumeric(x)&&isscalar(x)&&x>0);
parse(p,varargin{:});
opt=p.Results;

verbose=logical(opt.Verbose);
outDir=haps_new_output_dir(opt.OutputDir,'exact');

% Missing explicit inputs fail; no wildcard or alternate-file fallback.
shareFile=haps_require_file(opt.WorkloadShareFile);
alphaFile=haps_require_file(opt.AlphaFile);
nimFile=haps_require_file(opt.NIMBenchmarkFile);
hwFile=haps_require_file(opt.HardwareRegistryFile);
platFile=haps_require_file(opt.PlatformDeploymentsFile);
primaryModels=["llama31_8b_1xH100_fp8_TP1","llama33_70b_2xH100_fp8_TP2"];
threshold=double(opt.ReliabilityThreshold);

%% 1) Load workload p_k and baseline alpha_k
[pk,alphaBase]=load_workload_inputs(shareFile,alphaFile);
qBase=(pk./alphaBase); qBase=qBase/sum(qBase);

%% 2) Rebuild all seven general-SLO Cmax vectors from corrected NIM source
cmaxRegistryFile=fullfile(outDir,'general_slo_capacity.csv');
Tcmax=build_general_slo_cmax_registry(nimFile,cmaxRegistryFile, ...
    'TTFTLimitMs',2000,'ITLLimitMs',100);
Tcmax.model_key=string(Tcmax.model_key);
Tcmax.display_label=string(Tcmax.display_label);

if verbose
    fprintf('\n============================================================\n');
    fprintf('EXACT RELIABILITY FULL PIPELINE\n');
    fprintf('Overload criterion : %.4f%%\n',100*threshold);
    fprintf('Probability model  : independent Binomial activity\n');
    fprintf('Numerical method   : deterministic exact-under-model summation\n');
    fprintf('============================================================\n');
end

%% 3) Exact single-instance N95 for every general-SLO hardware configuration
Thw=readtable(hwFile,'VariableNamingRule','preserve');
requireColumnsLocal(Thw,["model_key","display_label","IT_power_kW","allocated_mass_kg"],hwFile);
Thw.model_key=string(Thw.model_key);
Thw.display_label=string(Thw.display_label);
if numel(unique(Thw.model_key))~=height(Thw)
    error('HAPS:HardwareRows','Hardware registry model keys must be unique.');
end

nCfg=height(Thw);
singleStructs=cell(nCfg,1);
rows=cell(nCfg,22);

for i=1:nCfg
    model=Thw.model_key(i);
    label=Thw.display_label(i);
    idx=find(Tcmax.model_key==model,1,'first');
    if isempty(idx), error('No Cmax registry row for %s.',model); end
    cmax=getCmaxVectorLocal(Tcmax(idx,:));
    feasible=all(isfinite(cmax)&cmax>0);

    if verbose
        fprintf('\n[%d/%d] single-instance: %s\n',i,nCfg,label);
    end

    if feasible
        initialGuess=NaN; % Bracket from nominal capacity, not an archived MC result.
        R=find_exact_reliability_threshold(pk,alphaBase,cmax, ...
            'ReliabilityThreshold',threshold, ...
            'InitialGuess',initialGuess, ...
            'NeighborhoodHalfWidth',3, ...
            'Verbose',verbose, ...
            'Label',label);
        singleStructs{i}=R;

        eff=R.N95/double(Thw.IT_power_kW(i));
        rows(i,:)={model,label,true,double(Thw.IT_power_kW(i)),double(Thw.allocated_mass_kg(i)), ...
            R.Cmix,R.Nharm,R.N95,R.P_at_N95,R.P_at_N95_plus_1,R.N95/R.Nharm,eff, ...
            R.Nk_at_N95(1),R.Nk_at_N95(2),R.Nk_at_N95(3),R.Nk_at_N95(4),R.Nk_at_N95(5), ...
            cmax(1),cmax(2),cmax(3),cmax(4),cmax(5)};

        safeName=safeNameLocal(model);
        writetable(R.neighborhood,fullfile(outDir,['neighborhood_single_' safeName '.csv']));
    else
        rows(i,:)={model,label,false,double(Thw.IT_power_kW(i)),double(Thw.allocated_mass_kg(i)), ...
            NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
            cmax(1),cmax(2),cmax(3),cmax(4),cmax(5)};
        singleStructs{i}=[];
    end
end

Tsingle=cell2table(rows,'VariableNames',singleVarNamesLocal());
Tsingle=normalizeSingleTableTypesLocal(Tsingle);
writetable(Tsingle,fullfile(outDir,'single_instance_exact.csv'));

%% 4) Exact source-data curves for the two Fig. 3d primary configurations
curveRows={};
if logical(opt.ComputePrimaryCurves)
    rr=double(opt.PrimaryCurveRatios(:));
    for im=1:numel(primaryModels)
        model=primaryModels(im);
        si=find(Tsingle.model_key==model,1,'first');
        if isempty(si)||~Tsingle.SLO_feasible(si), continue; end
        R=singleStructs{si};
        cmax=R.cmax;
        Nvec=unique([round(rr*R.Nharm); R.N95; R.N95+1; round(R.Nharm)]);
        Nvec=Nvec(Nvec>=0);
        alloc=buildAllocationPathLocal(max(Nvec),R.q);
        for ii=1:numel(Nvec)
            N=Nvec(ii);
            Nk=allocationAtNLocal(alloc,N);
            Pexact=exact_binomial_overload_probability(Nk,alphaBase,cmax);
            curveRows(end+1,:)={model,Tsingle.display_label(si),N,N/R.Nharm,Pexact,100*Pexact, ...
                Nk(1),Nk(2),Nk(3),Nk(4),Nk(5)}; %#ok<AGROW>
        end
    end
end
if isempty(curveRows)
    Tcurve=table();
else
    Tcurve=cell2table(curveRows,'VariableNames',{'model_key','display_label','N','N_over_Nharm', ...
        'P_overload_exact','P_overload_percent','N_A','N_B','N_C','N_D','N_E'});
end
writetable(Tcurve,fullfile(outDir,'primary_overload_curve.csv'));

%% 5) Exact pooled and exact static-balanced platform reliability
Tplat=readtable(platFile,'VariableNamingRule','preserve');
requireColumnsLocal(Tplat,["platform","model_key","m_instances"],platFile);
Tplat.platform=string(Tplat.platform);
Tplat.model_key=string(Tplat.model_key);
validateattributes(Tplat.m_instances,{'numeric'},{'finite','integer','nonnegative'});
if numel(unique(Tplat.platform+"|"+Tplat.model_key))~=height(Tplat)
    error('HAPS:PlatformRows','Require one deployment row per platform/model.');
end

platformRows=cell(height(Tplat),21);
platformStructs=cell(height(Tplat),2); % pooled, static
for i=1:height(Tplat)
    platform=Tplat.platform(i);
    model=Tplat.model_key(i);
    m=round(double(Tplat.m_instances(i)));
    si=find(Tsingle.model_key==model,1,'first');
    if isempty(si), error('Platform table model not in single registry: %s',model); end
    label=Tsingle.display_label(si);

    if verbose
        fprintf('\n[%d/%d] platform: %s | %s | m=%d\n',i,height(Tplat),platform,label,m);
    end

    if m<1 || ~Tsingle.SLO_feasible(si)
        platformRows(i,:)={platform,model,label,m,false,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN};
        continue;
    end

    Rsingle=singleStructs{si};
    cmax=Rsingle.cmax;
    linearRef=m*Rsingle.N95;

    if m==1
        Rpool=Rsingle;
        Rstatic=Rsingle;
    else
        Rpool=find_exact_reliability_threshold(pk,alphaBase,m*cmax, ...
            'ReliabilityThreshold',threshold, ...
            'InitialGuess',NaN, ...
            'NeighborhoodHalfWidth',2, ...
            'Verbose',verbose, ...
            'Label',platform+" pooled "+label);
        Rstatic=find_exact_static_balanced_threshold(pk,alphaBase,cmax,m, ...
            'ReliabilityThreshold',threshold, ...
            'InitialGuess',NaN, ...
            'NeighborhoodHalfWidth',2, ...
            'Verbose',verbose, ...
            'Label',platform+" static "+label);
    end
    platformStructs{i,1}=Rpool;
    platformStructs{i,2}=Rstatic;

    % Exact overload at the neutral linear m*N95 reference.
    NkLinear=allocationAtNLocal(buildAllocationPathLocal(linearRef,qBase),linearRef);
    PpoolAtLinear=exact_binomial_overload_probability(NkLinear,alphaBase,m*cmax);
    PstaticAtLinear=exact_static_balanced_overload_probability(NkLinear,alphaBase,cmax,m);

    poolGain=100*(Rpool.N95-linearRef)/linearRef;
    staticVsLinear=100*(Rstatic.N95-linearRef)/linearRef;
    poolVsStatic=100*(Rpool.N95-Rstatic.N95)/Rstatic.N95;

    platformRows(i,:)={platform,model,label,m,true,Rsingle.N95,linearRef, ...
        Rpool.N95,Rpool.P_at_N95,Rpool.P_at_N95_plus_1, ...
        Rstatic.N95,Rstatic.P_at_N95,Rstatic.P_at_N95_plus_1, ...
        PpoolAtLinear,PstaticAtLinear,poolGain,staticVsLinear,poolVsStatic, ...
        Rpool.Nk_at_N95(1),Rpool.Nk_at_N95(2),Rpool.Nk_at_N95(5)};

    safeName=[safeNameLocal(platform) '_' safeNameLocal(model)];
    writetable(Rpool.neighborhood,fullfile(outDir,['neighborhood_pooled_' safeName '.csv']));
    writetable(Rstatic.neighborhood,fullfile(outDir,['neighborhood_static_' safeName '.csv']));
end

Tplatform=cell2table(platformRows,'VariableNames',platformVarNamesLocal());
Tplatform=normalizePlatformTableTypesLocal(Tplatform);
writetable(Tplatform,fullfile(outDir,'platform_assignment_exact.csv'));

%% 6) Updated exact-convolution active-user quantiles for primary N95 values
trafficRows=cell(numel(primaryModels),13);
for im=1:numel(primaryModels)
    model=primaryModels(im);
    si=find(Tsingle.model_key==model,1,'first');
    R=singleStructs{si};
    Nk=R.Nk_at_N95;
    [meanAct,q50,q95,q99] = activeCountQuantilesLocal(Nk,alphaBase);
    bvec=double(opt.TrafficBytesPerToken(:));
    if numel(bvec)~=2, error('TrafficBytesPerToken must contain two endpoints, e.g. [4 6].'); end
    rateLow=8*double(opt.TrafficOverheadFactor)*bvec(1)*q95/(1000*double(opt.TrafficITLms));
    rateHigh=8*double(opt.TrafficOverheadFactor)*bvec(2)*q95/(1000*double(opt.TrafficITLms));
    allActiveLow=8*double(opt.TrafficOverheadFactor)*bvec(1)*R.N95/(1000*double(opt.TrafficITLms));
    allActiveHigh=8*double(opt.TrafficOverheadFactor)*bvec(2)*R.N95/(1000*double(opt.TrafficITLms));

    trafficRows(im,:)={model,Tsingle.display_label(si),R.N95,meanAct,q50,q95,q99,100*q95/R.N95, ...
        rateLow,rateHigh,allActiveLow,allActiveHigh,sum(Nk.*alphaBase)};
end
Ttraffic=cell2table(trafficRows,'VariableNames',{'model_key','display_label','N95_exact','mean_active', ...
    'P50_active','P95_active','P99_active','P95_active_fraction_percent', ...
    'P95_rate_low_Mbps','P95_rate_high_Mbps','all_active_rate_low_Mbps','all_active_rate_high_Mbps','mean_active_crosscheck'});
writetable(Ttraffic,fullfile(outDir,'activity_quantiles_exact.csv'));

%% 7) Fleet sizing from the highest exact pooled capacity on each platform
platforms=unique(Tplatform.platform(Tplatform.feasible));
targets=round(double(opt.TargetDemands(:)));
fleetRows={};
for ip=1:numel(platforms)
    plat=platforms(ip);
    mask=Tplatform.platform==plat & Tplatform.feasible;
    [bestCap,jj]=max(Tplatform.NHAPS95_pooled_exact(mask));
    sub=Tplatform(mask,:);
    bestModel=sub.model_key(jj);
    bestLabel=sub.display_label(jj);
    for it=1:numel(targets)
        H=ceil(targets(it)/bestCap);
        fleetRows(end+1,:)={plat,bestModel,bestLabel,bestCap,targets(it),H}; %#ok<AGROW>
    end
end
Tfleet=cell2table(fleetRows,'VariableNames',{'platform','best_model_key','best_display_label', ...
    'best_exact_NHAPS95','target_user_equivalents','minimum_active_HAPS_count'});
writetable(Tfleet,fullfile(outDir,'fleet_sizing_exact.csv'));

%% 8) Run manifest
Tmanifest=table(string(shareFile),string(alphaFile),string(nimFile),string(hwFile),string(platFile), ...
    threshold,"independent Binomial; exact deterministic tail summation", ...
    'VariableNames',{'workload_share_file','alpha_file','nim_benchmark_file','hardware_registry_file', ...
    'platform_deployments_file','overload_threshold','reliability_method'});
writetable(Tmanifest,fullfile(outDir,'run_manifest.csv'));

save(fullfile(outDir,'exact_workspace.mat'), ...
    'opt','pk','alphaBase','qBase','Tcmax','Thw','Tsingle','Tcurve','Tplat','Tplatform','Ttraffic','Tfleet');

if verbose
    fprintf('\n============================================================\n');
    fprintf('FULL EXACT RELIABILITY PIPELINE COMPLETE\n');
    fprintf('Output directory: %s\n',outDir);
    fprintf('============================================================\n');
    disp(Tsingle(:,{'display_label','SLO_feasible','Nharm','N95_exact','N95_over_Nharm','serving_efficiency_user_eq_per_kW'}));
    disp(Tplatform(:,{'platform','display_label','m_instances','linear_mN95_exact','NHAPS95_pooled_exact','NHAPS95_static_exact'}));
    disp(Tfleet);
end

out=struct();
out.cmax_registry=Tcmax;
out.single_instance=Tsingle;
out.primary_curve=Tcurve;
out.platform=Tplatform;
out.traffic=Ttraffic;
out.fleet=Tfleet;
out.manifest=Tmanifest;
out.output_dir=outDir;
end

%% ------------------------------------------------------------------------
% Local helpers
% -------------------------------------------------------------------------
function names=singleVarNamesLocal()
names={'model_key','display_label','SLO_feasible','IT_power_kW','allocated_mass_kg', ...
    'Cmix','Nharm','N95_exact','P_at_N95','P_at_N95_plus_1','N95_over_Nharm', ...
    'serving_efficiency_user_eq_per_kW','N_A','N_B','N_C','N_D','N_E', ...
    'Cmax_A','Cmax_B','Cmax_C','Cmax_D','Cmax_E'};
end

function names=platformVarNamesLocal()
names={'platform','model_key','display_label','m_instances','feasible','single_N95_exact', ...
    'linear_mN95_exact','NHAPS95_pooled_exact','P_pooled_at_NHAPS95','P_pooled_at_NHAPS95_plus_1', ...
    'NHAPS95_static_exact','P_static_at_NHAPS95','P_static_at_NHAPS95_plus_1', ...
    'P_pooled_at_linear_mN95','P_static_at_linear_mN95','pooled_gain_vs_linear_percent', ...
    'static_change_vs_linear_percent','pooled_gain_vs_static_percent','pooled_N_A','pooled_N_B','pooled_N_E'};
end

function T=normalizeSingleTableTypesLocal(T)
T.model_key=string(T.model_key);
T.display_label=string(T.display_label);
if iscell(T.SLO_feasible), T.SLO_feasible=cell2mat(T.SLO_feasible); end
numNames=setdiff(string(T.Properties.VariableNames),["model_key","display_label","SLO_feasible"]);
for ii=1:numel(numNames)
    v=char(numNames(ii));
    if iscell(T.(v)), T.(v)=cell2mat(T.(v)); end
end
end

function T=normalizePlatformTableTypesLocal(T)
T.platform=string(T.platform);
T.model_key=string(T.model_key);
T.display_label=string(T.display_label);
if iscell(T.feasible), T.feasible=cell2mat(T.feasible); end
numNames=setdiff(string(T.Properties.VariableNames),["platform","model_key","display_label","feasible"]);
for ii=1:numel(numNames)
    v=char(numNames(ii));
    if iscell(T.(v)), T.(v)=cell2mat(T.(v)); end
end
end

function c=getCmaxVectorLocal(row)
c=[double(row.Cmax_A);double(row.Cmax_B);double(row.Cmax_C);double(row.Cmax_D);double(row.Cmax_E)];
end

function [meanAct,q50,q95,q99]=activeCountQuantilesLocal(Nk,alpha)
% Full convolution of the five Binomial active-count distributions.
dist=1;
meanAct=sum(double(Nk(:)).*double(alpha(:)));
for k=1:5
    n=round(Nk(k));
    pm=binopdf(0:n,n,alpha(k));
    s=sum(pm);
    if s<=0, error('Invalid binomial PMF during active-count convolution.'); end
    pm=pm/s;
    dist=conv(dist,pm);
end
cdfv=cumsum(dist); cdfv=cdfv/cdfv(end);
q50=find(cdfv>=0.50,1,'first')-1;
q95=find(cdfv>=0.95,1,'first')-1;
q99=find(cdfv>=0.99,1,'first')-1;
end

function alloc=buildAllocationPathLocal(maxN,q)
maxN=round(maxN); q=double(q(:)); q=q/sum(q); K=numel(q);
alloc=zeros(maxN,K); counts=zeros(K,1);
for n=1:maxN
    target=n*q; deficit=target-counts; mx=max(deficit);
    cand=find(abs(deficit-mx)<1e-12);
    if numel(cand)>1
        [~,jj]=max(q(cand)); chosen=cand(jj);
    else
        chosen=cand(1);
    end
    counts(chosen)=counts(chosen)+1;
    alloc(n,:)=counts.';
end
end

function Nk=allocationAtNLocal(alloc,N)
N=round(N);
if N<=0, Nk=zeros(size(alloc,2),1); else, Nk=alloc(N,:).'; end
end

function requireColumnsLocal(T,names,fileName)
missing=names(~ismember(names,string(T.Properties.VariableNames)));
if ~isempty(missing)
    error('File %s is missing required column(s): %s',fileName,strjoin(missing,', '));
end
end

function s=safeNameLocal(x)
s=char(string(x));
s=regexprep(s,'[^A-Za-z0-9_-]','_');
end
