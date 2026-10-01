function out = run_serving_analysis(varargin)
% RUN_SERVING_ANALYSIS All-SLO extraction plus deterministic sensitivity only.
% Baseline linear and lower_step/pchip/log_linear alternatives share the same
% corrected NIM rows. No finite-snapshot N95 is calculated in this function.
p0=haps_paths;p=inputParser;
addParameter(p,'BenchmarkFile',fullfile(p0.processed,'nim_benchmark.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'WorkloadShareFile',fullfile(p0.processed,'workload_occupancy.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'AlphaFile',fullfile(p0.processed,'activity_statistics.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'MakeFigures',false,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});o=p.Results;outDir=haps_new_output_dir(o.OutputDir,'serving');
N=readtable(haps_require_file(o.BenchmarkFile),'TextType','string');
SLO=readtable(fullfile(p0.processed,'slo_definitions.csv'),'TextType','string');
[pk,alpha]=load_workload_inputs(o.WorkloadShareFile,o.AlphaFile);
models=unique(string(N.model_key),'stable');types=["A","B","C","D","E"];
methods=["linear","lower_step","pchip","log_linear"];
rows=cell(numel(models)*5*height(SLO)*numel(methods),12);r=0;
for im=1:numel(methods)
    for m=1:numel(models)
        for s=1:height(SLO)
            for k=1:5
                t=N(string(N.model_key)==models(m)&string(N.type_key)==types(k),:);
                if isempty(t),error('HAPS:MissingBenchmark','Missing model/type: %s %s.',models(m),types(k));end
                ct=serving_crossing(t.concurrency,t.ttft_ms,SLO.ttft_limit_ms(s),methods(im));
                ci=serving_crossing(t.concurrency,t.itl_ms,SLO.itl_limit_ms(s),methods(im));
                bottleneck="ITL";if ct<=ci,bottleneck="TTFT";end
                r=r+1;rows(r,:)={methods(im),models(m),types(k),SLO.SLO_key(s), ...
                    SLO.ttft_limit_ms(s),SLO.itl_limit_ms(s),ct,ci,min(ct,ci),bottleneck, ...
                    max(t.concurrency),min(ct,ci)==max(t.concurrency)};
            end
        end
    end
end
T=cell2table(rows,'VariableNames',{'method','model_key','type_key','SLO_key', ...
    'ttft_limit_ms','itl_limit_ms','Cmax_TTFT','Cmax_ITL','Cmax','bottleneck', ...
    'largest_measured_concurrency','capped_by_measured_range'});
writetable(T,fullfile(outDir,'capacity_interpolation.csv'));
linear=T(string(T.method)=="linear",:);writetable(linear,fullfile(outDir,'capacity_by_slo.csv'));
% The same general builder is used by the exact reliability pipeline.
general=build_general_slo_cmax_registry(o.BenchmarkFile,fullfile(outDir,'general_slo_capacity.csv'));
nominal=cell(numel(models)*numel(methods),7);budget=cell(numel(models)*5,5);r=0;b=0;
for m=1:numel(models)
    for im=1:numel(methods)
        t=T(string(T.model_key)==models(m)&string(T.method)==methods(im)&string(T.SLO_key)=="general",:);
        [tf,i]=ismember(types,string(t.type_key));if ~all(tf),error('HAPS:TypeRows','Missing type.');end
        cm=double(t.Cmax(i));cm=cm(:);feasible=all(cm>0&isfinite(cm));
        cmix=0;nh=0;if feasible,cmix=1/sum(pk./cm);nh=cmix*sum(pk./alpha);end
        r=r+1;nominal(r,:)={models(m),methods(im),cm(5),cmix,nh,feasible,"nominal only; not reliability N95"};
        if im==1
            frac=nan(5,1);if feasible,frac=(pk./cm)/sum(pk./cm);end
            for k=1:5,b=b+1;budget(b,:)={models(m),types(k),pk(k),cm(k),frac(k)};end
        end
    end
end
nominal=cell2table(nominal,'VariableNames',{'model_key','method','Cmax_E','Cmix','Nharm','SLO_feasible','interpretation'});
budget=cell2table(budget,'VariableNames',{'model_key','type_key','occupancy_fraction','Cmax','serving_budget_fraction'});
writetable(nominal,fullfile(outDir,'nominal_interpolation_sensitivity.csv'));
writetable(budget,fullfile(outDir,'serving_budget_contributions.csv'));
writetable(N,fullfile(outDir,'latency_curves.csv'));
% Check every archived primary interpolation crossing, not just headline Cmax.
ref=readtable(fullfile(p0.reference,'serving_capacity_interpolation.csv'),'TextType','string');
keys=string(T.method)+"|"+string(T.model_key)+"|"+string(T.SLO_key)+"|"+string(T.type_key);
rkeys=string(ref.method)+"|"+string(ref.model_key)+"|"+string(ref.SLO_key)+"|"+string(ref.type_key);
[tf,ix]=ismember(rkeys,keys);if ~all(tf),error('HAPS:ServingReference','Missing archived combinations.');end
err=double(T.Cmax(ix))-double(ref.Cmax);
cmp=table(rkeys,ref.Cmax,T.Cmax(ix),err,abs(err)<1e-8, ...
    'VariableNames',{'key','reference_Cmax','regenerated_Cmax','difference','passed'});
writetable(cmp,fullfile(outDir,'reference_comparison.csv'));
if ~all(cmp.passed),error('HAPS:ServingMismatch','An archived interpolation crossing differs; see reference_comparison.csv.');end
if o.MakeFigures,plot_serving_figures('ServingDir',outDir,'OutputDir',fullfile(outDir,'figures'));end
out=struct('output_dir',outDir,'capacity',T,'general',general,'nominal',nominal,'comparison',cmp);
fprintf('Serving analysis complete: %s\n',outDir);
end
