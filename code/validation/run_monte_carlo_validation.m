function out = run_monte_carlo_validation(varargin)
% RUN_MONTE_CARLO_VALIDATION Numerical validation only, never primary N95.
% Smoke: one seed, 5000 snapshots. Paper: source seeds [20260826,1:19],
% 100000 snapshots/seed, 20000-snapshot chunks for pooled runs. Chunking and
% draw order are part of the reproducibility protocol. Independent runs use
% frozen source lower anchors and the original deterministic sub-seed rule.
% Default performs no full 20-seed experiment. No raw snapshots are exported.
p0=haps_paths;p=inputParser;
addParameter(p,'Mode','smoke',@(x)ismember(string(x),["smoke","paper"]));
addParameter(p,'Protocol','pooled',@(x)ismember(string(x),["pooled","independent","both"]));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});o=p.Results;
if exist('binornd','file')~=2,error('HAPS:StatisticsToolbox','Monte-Carlo regeneration requires binornd.');end
outDir=haps_new_output_dir(o.OutputDir,'monte_carlo');
saved=rng;cleanup=onCleanup(@()rng(saved));
seeds=[20260826; (1:19).'];snapshots=100000;chunk=20000;
if string(o.Mode)=="smoke",seeds=seeds(1);snapshots=5000;chunk=5000;end
[pk,alpha]=load_workload_inputs;q=pk./alpha;q=q/sum(q);
S=readtable(fullfile(p0.reference,'exact','single_instance_exact.csv'),'TextType','string');
protocol=readtable(fullfile(p0.processed,'mc_seed_protocol.csv'),'TextType','string');
primary=["llama31_8b_1xH100_fp8_TP1","llama33_70b_2xH100_fp8_TP2"];
summaryParts=cell(2,1);diagnosticParts=cell(2,1);checks=cell(0,3);
for m=1:2
    t=S(string(S.model_key)==primary(m),:);cm=double(t{1,{'Cmax_A','Cmax_B','Cmax_C','Cmax_D','Cmax_E'}}).';
    exactN=double(t.N95_exact);stem=sprintf('model_%d',m);
    if ismember(string(o.Protocol),["pooled","both"])
        lo=exactN-15;hi=exactN+15;N=(lo:hi).';alloc=haps_allocation(hi,q);
        delta=diff(alloc(lo:hi,:),1,1);[~,addedType]=max(delta,[],2);
        counts=zeros(numel(N),numel(seeds));
        for j=1:numel(seeds)
            rng(seeds(j),'twister');done=0;
            while done<snapshots
                ns=min(chunk,snapshots-done);budget=zeros(ns,1);
                for k=1:5
                    if alloc(lo,k)>0,budget=budget+binornd(alloc(lo,k),alpha(k),ns,1)/cm(k);end
                end
                counts(1,j)=counts(1,j)+sum(budget>1);
                for n=2:numel(N)
                    k=addedType(n-1);budget=budget+double(rand(ns,1)<alpha(k))/cm(k);
                    counts(n,j)=counts(n,j)+sum(budget>1);
                end
                done=done+ns;
            end
            fprintf('%s pooled seed %d/%d complete\n',primary(m),j,numel(seeds));
        end
        total=numel(seeds)*snapshots;prob=sum(counts,2)/total;se=sqrt(prob.*(1-prob)/total);
        low=max(0,prob-1.96*se);high=min(1,prob+1.96*se);
        curve=table(N,sum(counts,2),repmat(total,numel(N),1),prob,100*prob,low,high,100*low,100*high, ...
            'VariableNames',{'N','overload_count','snapshots_per_N','P_overload_pooled', ...
            'P_overload_pooled_percent','CI95_low','CI95_high','CI95_low_percent','CI95_high_percent'});
        writetable(curve,fullfile(outDir,[stem '_pooled_curve.csv']));
        seedValues=nan(numel(seeds),1);left=false(numel(seeds),1);right=left;
        for j=1:numel(seeds)
            pp=counts(:,j)/snapshots;[seedValues(j),left(j),right(j)]=crossing(N,pp);
        end
        perSeed=table(seeds,seedValues,left,right,'VariableNames', ...
            {'seed','N95_fixed_path','left_censored','right_censored'});
        writetable(perSeed,fullfile(outDir,[stem '_pooled_per_seed.csv']));
        % Raw counts by seed allow independent pooling and CI checks.
        perCount=array2table(counts,'VariableNames',cellstr("seed_"+string(seeds.')));perCount=addvars(perCount,N,'Before',1);
        writetable(perCount,fullfile(outDir,[stem '_pooled_counts.csv']));
        [mcN,lc,rc]=crossing(N,prob);idx=find(N==exactN);
        compatible=t.P_at_N95>=low(idx)&&t.P_at_N95<=high(idx);
        summaryParts{m}=table(primary(m),string(o.Mode),exactN,mcN,mcN-exactN,total,lo,hi,lc,rc, ...
            prob(idx),low(idx),high(idx),compatible, ...
            'VariableNames',{'model_key','mode','exact_N95','pooled_MC_N95','delta_N', ...
            'snapshots_per_N','N_lower','N_upper','left_censored','right_censored', ...
            'P_at_exact_N95','CI95_low_at_exact','CI95_high_at_exact','exact_probability_in_MC_interval'});
        checks(end+1,:)={primary(m)+" pooled monotonicity",all(diff(prob)>=-1e-15),"Coupled path invariant"}; %#ok<AGROW>
    end
    if ismember(string(o.Protocol),["independent","both"])
        pr=protocol(string(protocol.model_key)==primary(m),:);anchor=pr.fixed_lower_anchor_N;
        maxN=anchor+pr.max_additional_users;alloc=haps_allocation(maxN,q);seedRows=cell(numel(seeds),9);
        for j=1:numel(seeds)
            subSeed=mod(round(double(seeds(j))+1000003*double(pr.model_index)+1009+7919*2),2^31-2)+1;
            rng(subSeed,'twister');budget=zeros(snapshots,1);prev=zeros(1,5);
            N=(anchor:maxN).';P=nan(size(N));last=numel(N);
            for n=1:numel(N)
                nk=alloc(N(n),:);d=nk-prev;
                for k=1:5
                    if d(k)>0,budget=budget+binornd(d(k),alpha(k),snapshots,1)/cm(k);end
                end
                P(n)=mean(budget>1);prev=nk;
                if P(n)>.05,last=n;break;end
            end
            N=N(1:last);P=P(1:last);[n95,lc,rc]=crossing(N,P);
            pn=NaN;pn1=NaN;
            if ~lc&&~rc,pn=P(end-1);pn1=P(end);end
            seedRows(j,:)={seeds(j),subSeed,anchor,n95,lc,rc,pn,pn1,exactN};
            writetable(table(N,P,'VariableNames',{'N','P_overload'}), ...
                fullfile(outDir,sprintf('%s_independent_seed_%d_curve.csv',stem,seeds(j))));
            fprintf('%s independent seed %d/%d complete\n',primary(m),j,numel(seeds));
        end
        independent=cell2table(seedRows,'VariableNames',{'base_seed','refinement_seed','fixed_lower_anchor', ...
            'N95','left_censored','right_censored','P_at_N95','P_at_N95_plus_1','exact_reference_N95'});
        writetable(independent,fullfile(outDir,[stem '_independent_per_seed.csv']));
        valid=~independent.left_censored&~independent.right_censored;
        v=independent.N95(valid);
        avg=NaN;med=NaN;sd=NaN;mn=NaN;mx=NaN;
        if ~isempty(v),avg=mean(v);med=median(v);sd=std(v);mn=min(v);mx=max(v);end
        diagnosticParts{m}=table(primary(m),string(o.Mode),numel(seeds),sum(valid),avg,med,sd,mn,mx, ...
            'VariableNames',{'model_key','mode','seeds_requested','fully_bracketed_seeds','mean_N95', ...
            'median_N95','std_N95','min_N95','max_N95'});
        checks(end+1,:)={primary(m)+" independent brackets",all(valid),"Not an interval on exact model capacity"}; %#ok<AGROW>
    end
end
pooled=table();independent=table();
if ~isempty(summaryParts{1}),pooled=vertcat(summaryParts{:});writetable(pooled,fullfile(outDir,'pooled_summary.csv'));end
if ~isempty(diagnosticParts{1}),independent=vertcat(diagnosticParts{:});writetable(independent,fullfile(outDir,'independent_summary.csv'));end

if string(o.Mode)=="paper"
    comparisonRows=cell(0,6);
    if ~isempty(pooled)
        family=["8b","70b"];
        for i=1:2
            old=readtable(fullfile(p0.reference,'validation',family(i)+"_pooled_mc_summary.csv"));
            comparisonRows(end+1,:)={primary(i),"pooled_N95",pooled.pooled_MC_N95(i), ...
                old.N95_pooled_MC(1),pooled.pooled_MC_N95(i)-old.N95_pooled_MC(1), ...
                pooled.pooled_MC_N95(i)==old.N95_pooled_MC(1)}; %#ok<AGROW>
        end
    end
    if ~isempty(independent)
        old=readtable(fullfile(p0.reference,'validation','independent_seed_diagnostic_per_seed.csv'),'TextType','string');
        for i=1:2
            ref=old.N95(string(old.model_key)==primary(i));refStats=[mean(ref),median(ref),std(ref),min(ref),max(ref)];
            newStats=[independent.mean_N95(i),independent.median_N95(i),independent.std_N95(i),independent.min_N95(i),independent.max_N95(i)];
            names=["mean","median","sample_std","min","max"];
            for j=1:5
                comparisonRows(end+1,:)={primary(i),"independent_"+names(j),newStats(j),refStats(j), ...
                    newStats(j)-refStats(j),abs(newStats(j)-refStats(j))<1e-8}; %#ok<AGROW>
            end
        end
    end
    comparison=cell2table(comparisonRows,'VariableNames',{'model_key','statistic','regenerated','reference','difference','same_within_tolerance'});
    writetable(comparison,fullfile(outDir,'reference_comparison.csv'));
end

report=cell2table(checks,'VariableNames',{'check','passed','detail'});writetable(report,fullfile(outDir,'invariant_checks.csv'));
config=table(string(o.Mode),string(o.Protocol),snapshots,chunk,numel(seeds), ...
    'VariableNames',{'mode','protocol','snapshots_per_seed','chunk_size','num_seeds'});
writetable(config,fullfile(outDir,'run_configuration.csv'));writetable(table(seeds),fullfile(outDir,'seeds.csv'));
record_environment(fullfile(outDir,'matlab_environment.csv'));
out=struct('output_dir',outDir,'mode',string(o.Mode),'pooled',pooled,'independent',independent,'checks',report);
fprintf('MC %s run complete. This is not the primary exact-capacity calculation: %s\n',o.Mode,outDir);
end

function [n95,left,right] = crossing(N,P)
% Missing bracket is represented by NaN, not a reported threshold.
left=P(1)>.05;right=P(end)<=.05;n95=NaN;
if ~left&&~right
    i=find(P>.05,1);n95=N(i-1);
end
end
