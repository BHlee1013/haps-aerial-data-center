function out = plot_workload_figures(varargin)
% PLOT_WORKLOAD_FIGURES Fig. 2 and SI Fig. 1 from stored or regenerated data.
% Without raw-derived token_density.csv, Fig. 2a is explicitly skipped. The
% optional frozen tau curve is a manuscript-rounded display reference only.
p0=haps_paths;p=inputParser;
addParameter(p,'WorkloadDir',p0.processed,@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});o=p.Results;outDir=haps_new_output_dir(o.OutputDir,'workload_figures');
O=readtable(haps_require_file(fullfile(o.WorkloadDir,'workload_occupancy.csv')),'TextType','string');
A=readtable(haps_require_file(fullfile(o.WorkloadDir,'activity_statistics.csv')),'TextType','string');
files=strings(0,1);skipped=strings(0,1);
f=figure('Color','w','Visible','off','Position',[100 100 780 480]);ax=axes(f);
bar(ax,100*[O.RequestCountShare,O.ElapsedTimeShare_p_k]);
set(ax,'XTick',1:5,'XTickLabel',cellstr(O.Type));xlabel(ax,'Workload type');ylabel(ax,'Share (%)');
legend(ax,{'Request-count share','Elapsed-time occupancy'},'Location','best');grid(ax,'on');
haps_export_figure(f,outDir,'fig02b_workload_occupancy',O);files(end+1)="fig02b_workload_occupancy";
f=figure('Color','w','Visible','off','Position',[100 100 720 460]);ax=axes(f);
errorbar(ax,1:5,100*A.alpha_baseline,100*(A.alpha_baseline-A.alpha_bootstrap_p025), ...
    100*(A.alpha_bootstrap_p975-A.alpha_baseline),'o','LineWidth',1.2);
set(ax,'XTick',1:5,'XTickLabel',cellstr(A.Type));xlabel(ax,'Workload type');ylabel(ax,'Active-user fraction (%)');grid(ax,'on');
haps_export_figure(f,outDir,'fig02c_activity_bootstrap',A);files(end+1)="fig02c_activity_bootstrap";
densityFile=fullfile(o.WorkloadDir,'token_density.csv');
if isfile(densityFile)
    T=readtable(densityFile);nx=max(T.input_bin);ny=max(T.output_bin);
    H=accumarray([T.input_bin,T.output_bin],T.count,[nx,ny]);
    xx=unique(T.input_log10_1p,'sorted');yy=unique(T.output_log10_1p,'sorted');
    f=figure('Color','w','Visible','off','Position',[100 100 800 620]);ax=axes(f);
    h=imagesc(ax,xx,yy,log10(H.'+1));set(h,'AlphaData',H.'>0);axis(ax,'xy');hold(ax,'on');
    types=readtable(fullfile(p0.processed,'workload_type_definitions.csv'),'TextType','string');
    cx=log10(types.center_input_tokens+1);cy=log10(types.center_output_tokens+1);
    scatter(ax,cx,cy,55,'w','filled','MarkerEdgeColor','k');
    for k=1:5,text(ax,cx(k)+.04,cy(k)+.04,types.Type(k),'FontWeight','bold');end
    cb=colorbar(ax);cb.Label.String='log_{10}(count + 1)';
    tokenTicks=[0 10 100 1000 10000 100000];tick=log10(tokenTicks+1);
    xticks(ax,tick);yticks(ax,tick);xticklabels(ax,string(tokenTicks));yticklabels(ax,string(tokenTicks));
    xlabel(ax,'Input tokens');ylabel(ax,'Output tokens');
    haps_export_figure(f,outDir,'fig02a_token_density',T);files(end+1)="fig02a_token_density";
else
    skipped(end+1)="Fig. 2a requires raw-derived token_density.csv; run_workload_analysis produces it.";
end
tauFile=fullfile(o.WorkloadDir,'tau_sensitivity.csv');rounded=false;
if isfile(tauFile)
    T=readtable(tauFile,'TextType','string');T.alpha_percent=100*T.alpha;
else
    tauFile=fullfile(p0.reference,'workload','tau_sensitivity_display_reference.csv');
    T=readtable(tauFile,'TextType','string');rounded=true;
end
f=figure('Color','w','Visible','off','Position',[100 100 900 470]);ax=axes(f);hold(ax,'on');
for k=["A","B","C","D","E"]
    t=sortrows(T(string(T.Type)==k,:),'tau_s');plot(ax,t.tau_s,t.alpha_percent,'-o','DisplayName',"Type "+k);
end
xlabel(ax,'Session-continuity threshold (s)');ylabel(ax,'Active-user fraction (%)');legend(ax,'Location','best');grid(ax,'on');
if rounded,title(ax,'Manuscript-rounded display reference; rerun raw trace for full precision');end
haps_export_figure(f,outDir,'supp_fig01_activity_vs_tau',T);files(end+1)="supp_fig01_activity_vs_tau";
writetable(table(files),fullfile(outDir,'figure_manifest.csv'));
out=struct('output_dir',outDir,'figures',files,'skipped',skipped,'tau_uses_rounded_reference',rounded);
if ~isempty(skipped),fprintf('%s\n',skipped);end
end
