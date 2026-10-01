function T = build_general_slo_cmax_registry(nimBenchmarkFile,outputFile,varargin)
% BUILD_GENERAL_SLO_CMAX_REGISTRY
% Reconstructs the general-SLO Cmax registry directly from the corrected
% NVIDIA NIM benchmark table using the manuscript method:
%   1) sort by concurrency;
%   2) replace TTFT/ITL by non-decreasing envelopes;
%   3) locate the SLO crossing with piecewise-linear interpolation;
%   4) do not extrapolate beyond the measured concurrency range;
%   5) Cmax = min(C_TTFT,C_ITL).

p=inputParser;
addParameter(p,'TTFTLimitMs',2000,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'ITLLimitMs',100,@(x)isnumeric(x)&&isscalar(x)&&x>0);
parse(p,varargin{:});
opt=p.Results;
if opt.TTFTLimitMs~=2000 || opt.ITLLimitMs~=100
    error('HAPS:UnsupportedSLO','This general-SLO builder emits only the general 2000/100-ms SLO registry.');
end

if nargin<2 || isempty(outputFile)
    error('HAPS:OutputRequired','Pass an explicit output file.');
end

outputFile=haps_new_output_file(outputFile);
nimBenchmarkFile=haps_require_file(nimBenchmarkFile);
Tin=readtable(nimBenchmarkFile,'VariableNamingRule','preserve');
need=["model_key","type_key","concurrency","ttft_ms","itl_ms"];
missing=need(~ismember(need,string(Tin.Properties.VariableNames)));
if ~isempty(missing)
    error('NIM benchmark file missing columns: %s',strjoin(missing,', '));
end

Tin.model_key=string(Tin.model_key);
Tin.type_key=upper(strtrim(string(Tin.type_key)));
models=unique(Tin.model_key,'stable');
ORDER=["A","B","C","D","E"];

labels=strings(numel(models),1);
Cmat=nan(numel(models),5);
feasible=false(numel(models),1);
for im=1:numel(models)
    model=models(im);
    cvals=nan(1,5);
    cttft=nan(1,5);
    citl=nan(1,5);
    for k=1:5
        mask=Tin.model_key==model & Tin.type_key==ORDER(k);
        G=Tin(mask,:);
        if isempty(G)
            error('Missing NIM rows for model=%s type=%s.',model,ORDER(k));
        end
        [~,ix]=sort(double(G.concurrency));
        x=double(G.concurrency(ix));
        if any(~isfinite(x)|x<=0) || any(diff(x)<=0)
            error('HAPS:InvalidBenchmark','Concurrency must be positive, finite and unique.');
        end
        if any(~isfinite(G.ttft_ms)|G.ttft_ms<0) || any(~isfinite(G.itl_ms)|G.itl_ms<0)
            error('HAPS:InvalidBenchmark','Latency must be finite and nonnegative.');
        end
        yT=cummax(double(G.ttft_ms(ix)));
        yI=cummax(double(G.itl_ms(ix)));
        cttft(k)=crossingCapacityLocal(x,yT,opt.TTFTLimitMs);
        citl(k)=crossingCapacityLocal(x,yI,opt.ITLLimitMs);
        cvals(k)=min(cttft(k),citl(k));
    end
    labels(im)=displayLabelLocal(model);
    Cmat(im,:)=cvals;
    feasible(im)=all(isfinite(cvals)&cvals>0);
end

T=table(models,labels,Cmat(:,1),Cmat(:,2),Cmat(:,3),Cmat(:,4),Cmat(:,5),feasible, ...
    repmat("general",numel(models),1), ...
    'VariableNames',{'model_key','display_label','Cmax_A','Cmax_B','Cmax_C','Cmax_D','Cmax_E','SLO_feasible','SLO_key'});
writetable(T,outputFile);
end

function c=crossingCapacityLocal(x,y,limit)
x=double(x(:)); y=double(y(:));
if y(1)>limit
    c=0;
    return;
end
if all(y<=limit)
    c=x(end); % capped by largest measured concurrency; no extrapolation
    return;
end
j=find(y>limit,1,'first');
i=j-1;
if y(j)==y(i)
    c=x(i);
else
    c=x(i)+(limit-y(i))/(y(j)-y(i))*(x(j)-x(i));
end
end

function s=displayLabelLocal(model)
model=string(model);
s=model;
s=replace(s,"llama31_8b_1xH100_fp8_TP1","8B / 1xH100");
s=replace(s,"llama31_8b_1xH200_fp8_TP1","8B / 1xH200");
s=replace(s,"llama31_8b_1xL40S_fp8_TP1","8B / 1xL40S");
s=replace(s,"llama33_70b_2xH100_fp8_TP2","70B / 2xH100");
s=replace(s,"llama33_70b_2xH200_fp8_TP2","70B / 2xH200");
s=replace(s,"llama33_70b_4xH100_fp8_TP4","70B / 4xH100");
s=replace(s,"llama33_70b_8xA100_bf16_TP8","70B / 8xA100");
end
