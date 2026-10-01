function out = plot_serving_figures(varargin)
% PLOT_SERVING_FIGURES Main Fig. 3a-c from the shared NIM/SLO calculation.
p=inputParser;addParameter(p,'ServingDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'serving_figures');
N=readtable(haps_require_file(fullfile(o.ServingDir,'latency_curves.csv')),'TextType','string');
C=readtable(haps_require_file(fullfile(o.ServingDir,'capacity_by_slo.csv')),'TextType','string');
B=readtable(haps_require_file(fullfile(o.ServingDir,'serving_budget_contributions.csv')),'TextType','string');
models=["llama31_8b_1xH100_fp8_TP1","llama33_70b_2xH100_fp8_TP2"];
labels=["8B / 1xH100","70B / 2xH100"];types=["A","B","C","D","E"];
f=figure('Color','w','Visible','off','Position',[100 100 1100 730]);tl=tiledlayout(f,2,2,'TileSpacing','compact');
for metric=1:2
    for m=1:2
        ax=nexttile(tl);hold(ax,'on');
        for k=types
            t=sortrows(N(string(N.model_key)==models(m)&string(N.type_key)==k,:),'concurrency');
            if metric==1,y=t.ttft_ms;else,y=t.itl_ms;end
            plot(ax,t.concurrency,y,'-o','DisplayName',"Type "+k);
        end
        if metric==1,set(ax,'YScale','log');ylabel(ax,'TTFT (ms)');yline(ax,2000,'--','2000 ms','HandleVisibility','off');
        else,ylabel(ax,'ITL (ms)');yline(ax,100,'--','100 ms','HandleVisibility','off');end
        xlabel(ax,'Concurrency');title(ax,labels(m),'Interpreter','none');grid(ax,'on');
        if metric==2&&m==1,legend(ax,'Location','best');end
    end
end
haps_export_figure(f,outDir,'fig03a_latency_curves',N(ismember(string(N.model_key),models),:));
f=figure('Color','w','Visible','off','Position',[100 100 1100 500]);tl=tiledlayout(f,1,2,'TileSpacing','compact');
slo=["general","ttft_strict","itl_strict"];selected=C(ismember(string(C.model_key),models)&ismember(string(C.SLO_key),slo),:);
for m=1:2
    ax=nexttile(tl);Y=nan(5,3);
    for k=1:5
        for j=1:3
            t=selected(string(selected.model_key)==models(m)&string(selected.type_key)==types(k)&string(selected.SLO_key)==slo(j),:);
            if height(t)~=1,error('HAPS:ServingPlot','Require one model/type/SLO row.');end
            Y(k,j)=t.Cmax;
        end
    end
    bar(ax,Y);set(ax,'XTick',1:5,'XTickLabel',cellstr(types));ylim(ax,[0 285]);
    ylabel(ax,'SLO-constrained concurrency');xlabel(ax,'Workload type');title(ax,labels(m),'Interpreter','none');
    if m==1,legend(ax,{'2000 / 100 ms','1000 / 100 ms','2000 / 40 ms'},'Location','best');end
    grid(ax,'on');
end
haps_export_figure(f,outDir,'fig03b_slo_capacity',selected);
f=figure('Color','w','Visible','off','Position',[100 100 850 500]);ax=axes(f);Y=zeros(5,2);
for m=1:2
    t=B(string(B.model_key)==models(m),:);[~,i]=ismember(types,string(t.type_key));Y(:,m)=100*t.serving_budget_fraction(i);
end
bar(ax,Y);hold(ax,'on');plot(ax,1:5,100*t.occupancy_fraction(i),'k-o');
set(ax,'XTick',1:5,'XTickLabel',cellstr(types));ylabel(ax,'Share (%)');xlabel(ax,'Workload type');
legend(ax,{'8B serving budget','70B serving budget','Elapsed-time occupancy'},'Location','best');grid(ax,'on');
haps_export_figure(f,outDir,'fig03c_serving_budget',B(ismember(string(B.model_key),models),:));
out=struct('output_dir',outDir);
end
