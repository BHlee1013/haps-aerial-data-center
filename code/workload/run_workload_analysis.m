function out = run_workload_analysis(varargin)
% RUN_WORKLOAD_ANALYSIS Raw BurstGPT -> occupancy/activity/bootstrap/mapping.
% Requests without usable Session IDs are excluded from session-pair construction
% and counted in input_summary.csv; no session identity is imputed.
% Defaults reproduce tau=1800 s, 1000 day-bootstrap replicates, seed=1.
% The bootstrap samples the days of the FULL valid-pair table before tau;
% daily sufficient statistics replace concatenation without changing the
% alpha estimator. This is not a bootstrap of service reliability or N95.
% All files are written in a NEW output folder; packaged references stay fixed.
p0=haps_paths;p=inputParser;
addParameter(p,'BurstGPTFile','',@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'Tau',1800,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'TauList',[600 1800 3600],@(x)isnumeric(x)&&isvector(x)&&all(isfinite(x)&x>0));
addParameter(p,'NumBootstrap',1000,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&fix(x)==x);
addParameter(p,'Seed',1,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&fix(x)==x);
addParameter(p,'MakeFigures',true,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});o=p.Results;
if strlength(string(o.BurstGPTFile))==0
    error('HAPS:RawTraceRequired','Pass the local original BurstGPT CSV using BurstGPTFile. It is not bundled.');
end
outDir=haps_new_output_dir(o.OutputDir,'workload');
[pairs,importInfo]=load_burstgpt_pairs(o.BurstGPTFile);
writetable(importInfo,fullfile(outDir,'input_summary.csv'));
T=pairs(pairs.dt_s<=o.Tau,:);
if isempty(T),error('HAPS:EmptyWorkload','No pairs satisfy the requested tau.');end
[label,M,dist]=classify_workload_pairs(T);
R=double(T.elapsed_s);Z=max(T.dt_s-R,0);types=["A";"B";"C";"D";"E"];
count=accumarray(label,1,[5,1]);elapsed=accumarray(label,R,[5,1]);
occ=table(types,count,count/sum(count),elapsed,elapsed/sum(elapsed), ...
    'VariableNames',{'Type','RequestCount','RequestCountShare','ElapsedTime_s','ElapsedTimeShare_p_k'});
writetable(occ,fullfile(outDir,'workload_occupancy.csv'));
a=summarize_pair_activity(T,M);
% Retain no-priority range alpha at each session threshold.
taus=unique([o.TauList(:);o.Tau]);parts=cell(numel(taus),1);
for j=1:numel(taus)
    Q=pairs(pairs.dt_s<=taus(j),:);[~,mq]=classify_workload_pairs(Q);
    t=summarize_pair_activity(Q,mq);t.tau_s=repmat(taus(j),height(t),1);parts{j}=t;
end
tauTable=vertcat(parts{:});writetable(tauTable,fullfile(outDir,'tau_sensitivity.csv'));
% All five alternative activity estimators, on the same retained pair set.
methods=["baseline","overlap_distance","b_over_c","c_over_b","global_distance"];
mlabels=["Overlapping windows","Overlap-only distance","B-over-C priority","C-over-B priority","Global distance"];
map=zeros(5,5);map(1,:)=a.alpha.';
gated=dist;gated(~M)=Inf;[~,over]=min(gated,[],2);over(~any(M,2))=0;
labels=cell(1,4);labels{1}=over;
for ip=1:2
    order=[1 2 3 4 5];if ip==2,order=[1 3 2 4 5];end
    v=zeros(height(T),1);
    for k=order,v(v==0&M(:,k))=k;end
    labels{ip+1}=v;
end
labels{4}=label;
for j=1:4
    mm=labels{j}==(1:5);t=summarize_pair_activity(T,mm);map(j+1,:)=t.alpha.';
end
mapping=table(methods.',mlabels.',map(:,1),map(:,2),map(:,3),map(:,4),map(:,5), ...
    'VariableNames',{'mapping_key','mapping_label','alpha_A','alpha_B','alpha_C','alpha_D','alpha_E'});
writetable(mapping,fullfile(outDir,'mapping_activity.csv'));
overlap=table(sum(M(:,2)&M(:,3)),sum(M(:,2)&M(:,3)&over==2), ...
    sum(M(:,2)&M(:,3)&over==3),'VariableNames',{'B_C_overlap_pairs','assigned_to_B','assigned_to_C'});
writetable(overlap,fullfile(outDir,'mapping_overlap_diagnostics.csv'));
% Bootstrap sums are indexed in exactly the source unique(...,'stable') day order.
days=unique(pairs.day_block,'stable');[~,id]=ismember(T.day_block,days);nd=numel(days);
sr=zeros(nd,5);sz=zeros(nd,5);nn=zeros(nd,5);
for k=1:5
    sr(:,k)=accumarray(id(M(:,k)),R(M(:,k)),[nd,1]);
    sz(:,k)=accumarray(id(M(:,k)),Z(M(:,k)),[nd,1]);
    nn(:,k)=accumarray(id(M(:,k)),1,[nd,1]);
end
savedRng=rng;guard=onCleanup(@()rng(savedRng));rng(o.Seed,'twister');
B=o.NumBootstrap;ba=nan(B,5);bn=zeros(B,5);
for b=1:B
    take=randi(nd,[nd,1]);br=sum(sr(take,:),1);bz=sum(sz(take,:),1);
    ba(b,:)=br./(br+bz);bn(b,:)=sum(nn(take,:),1);
end
summary=table(types,a.alpha,100*a.alpha,a.n_pairs,a.mean_R_s,a.mean_Z_s, ...
    'VariableNames',{'Type','alpha_baseline','alpha_baseline_percent','n_pairs_baseline', ...
    'mean_R_s_baseline','mean_Z_s_baseline'});
mu=nan(5,1);sd=mu;lo=mu;med=mu;hi=mu;finiteCount=zeros(5,1);
for k=1:5
    vals=ba(isfinite(ba(:,k)),k);finiteCount(k)=numel(vals);
    if ~isempty(vals)
        mu(k)=mean(vals);sd(k)=std(vals);qq=prctile(vals,[2.5 50 97.5]);
        lo(k)=qq(1);med(k)=qq(2);hi(k)=qq(3);
    end
end
summary.alpha_bootstrap_mean=mu;summary.alpha_bootstrap_std=sd;
summary.alpha_bootstrap_p025=lo;summary.alpha_bootstrap_p500=med;summary.alpha_bootstrap_p975=hi;
summary.alpha_bootstrap_p025_percent=100*lo;summary.alpha_bootstrap_p500_percent=100*med;
summary.alpha_bootstrap_p975_percent=100*hi;summary.NumFiniteBootstrap=finiteCount;
writetable(summary,fullfile(outDir,'activity_statistics.csv'));
boot=table(repelem((1:B).',5),repmat(types,B,1),reshape(ba.',[],1), ...
    reshape(bn.',[],1),'VariableNames',{'replicate','Type','alpha_range','n_pairs'});
writetable(boot,fullfile(outDir,'activity_bootstrap_replicates.csv'));
% Fig. 2a: same 90x90 log10(1+tokens) histogram of tau-filtered initiating pairs.
x=log10(T.input_tokens+1);y=log10(T.output_tokens+1);
xe=linspace(min(x),max(x),91);ye=linspace(min(y),max(y),91);
if xe(1)==xe(end),xe=linspace(xe(1)-.1,xe(end)+.1,91);end
if ye(1)==ye(end),ye=linspace(ye(1)-.1,ye(end)+.1,91);end
H=histcounts2(x,y,xe,ye);[ix,iy]=ndgrid(1:90,1:90);
xc=(xe(1:end-1)+xe(2:end))/2;yc=(ye(1:end-1)+ye(2:end))/2;
density=table(ix(:),iy(:),reshape(xc(ix),[],1),reshape(yc(iy),[],1),H(:), ...
    'VariableNames',{'input_bin','output_bin','input_log10_1p','output_log10_1p','count'});
writetable(density,fullfile(outDir,'token_density.csv'));
config=table(o.Tau,B,o.Seed,nd,string(haps_sha256(o.BurstGPTFile)), ...
    'VariableNames',{'tau_s','bootstrap_replicates','seed','day_blocks_before_tau','raw_sha256'});
writetable(config,fullfile(outDir,'run_configuration.csv'));
% Comparison is against archived data, never an automatic overwrite of it.
refO=readtable(fullfile(p0.processed,'workload_occupancy.csv'),'TextType','string');
refA=readtable(fullfile(p0.processed,'activity_statistics.csv'),'TextType','string');
cmp=table(types,occ.ElapsedTimeShare_p_k,refO.ElapsedTimeShare_p_k, ...
    a.alpha,refA.alpha_baseline,'VariableNames', ...
    {'Type','regenerated_pk','reference_pk','regenerated_alpha','reference_alpha'});
cmp.pk_difference=cmp.regenerated_pk-cmp.reference_pk;cmp.alpha_difference=cmp.regenerated_alpha-cmp.reference_alpha;
writetable(cmp,fullfile(outDir,'baseline_comparison.csv'));
record_environment(fullfile(outDir,'matlab_environment.csv'));
if o.MakeFigures,plot_workload_figures('WorkloadDir',outDir,'OutputDir',fullfile(outDir,'figures'));end
out=struct('output_dir',outDir,'occupancy',occ,'activity',summary,'mapping',mapping,'comparison',cmp);
fprintf('Workload analysis complete: %s\n',outDir);
end
