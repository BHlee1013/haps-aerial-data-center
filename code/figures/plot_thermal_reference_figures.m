function out = plot_thermal_reference_figures(varargin)
% PLOT_THERMAL_REFERENCE_FIGURES Replot archived E2-E4 data; never calls sim.
% Stored failed-run records are retained in data/results/reference/thermal.
p0=haps_paths;p=inputParser;
addParameter(p,'ThermalDir',fullfile(p0.reference,'thermal'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));parse(p,varargin{:});o=p.Results;
outDir=haps_new_output_dir(o.OutputDir,'thermal_figures');
T=readtable(fullfile(o.ThermalDir,'map','Fig4b_v3_dense_12h_summary.csv'),'TextType','string');
x=unique(T.UA_external_W_K);y=unique(T.G_wall_W_K);[~,ix]=ismember(T.UA_external_W_K,x);[~,iy]=ismember(T.G_wall_W_K,y);
Z=nan(numel(y),numel(x));RPM=Z;
for i=1:height(T),Z(iy(i),ix(i))=T.fan_overhead_percent(i);RPM(iy(i),ix(i))=T.min_feasible_rpm(i);end
f=figure('Color','w','Visible','off','Position',[100 100 950 610]);ax=axes(f);
contourf(ax,x,log10(y),Z,25,'LineColor','none');hold(ax,'on');
contour(ax,x,log10(y),Z,[5 5],'k--','LineWidth',1.2);
contour(ax,x,log10(y),RPM,[5000 5000],'w-','LineWidth',1.2);
missing=~isfinite(T.fan_overhead_percent);plot(ax,T.UA_external_W_K(missing),log10(T.G_wall_W_K(missing)),'kx','MarkerSize',3);
yticks(ax,1:6);yticklabels(ax,{'10^1','10^2','10^3','10^4','10^5','10^6'});
xlabel(ax,'External heat-rejection conductance (W/K)');ylabel(ax,'Wall/feedthrough conductance (W/K)');
cb=colorbar(ax);cb.Label.String='Fan electrical power / IT power (%)';
title(ax,'Archived 1.1-kW thermal feasibility map');
haps_export_figure(f,outDir,'fig04b_thermal_map',T);
T=readtable(fullfile(o.ThermalDir,'duct','thermal_v5_duct_fine_summary.csv'),'TextType','string');
T=T(string(T.case_source)=="duct_fine",:);T=sortrows(T,'duct_area_scale');
f=figure('Color','w','Visible','off','Position',[100 100 800 480]);ax=axes(f);
plot(ax,T.duct_area_scale,T.fan_overhead_percent,'-o');grid(ax,'on');
xlabel(ax,'Common duct-area scale');ylabel(ax,'Minimum fan electrical power / IT (%)');
haps_export_figure(f,outDir,'fig04c_duct_scale',T);
T=readtable(fullfile(o.ThermalDir,'robustness','thermal_fig4d_robustness_summary.csv'),'TextType','string');
groups=["fig4d_reference","thermal_margin","environment_corner"];sel=ismember(string(T.validation_group),groups);T=T(sel,:);
f=figure('Color','w','Visible','off','Position',[100 100 920 450]);ax=axes(f);hold(ax,'on');
for g=1:3
    t=T(string(T.validation_group)==groups(g),:);yy=repmat(g,height(t),1);
    scatter(ax,t.fan_overhead_percent,yy,45,'filled');
    high=t.min_feasible_rpm>5000;plot(ax,t.fan_overhead_percent(high),yy(high),'kx','MarkerSize',10,'LineWidth',1.3);
end
set(ax,'YTick',1:3,'YTickLabel',{'Selected reference','Thermal margin','Environment corners'},'YDir','reverse');
xline(ax,2,'--','2%');xline(ax,5,'--','5%');xlabel(ax,'Minimum fan electrical power / IT (%)');ylim(ax,[.5 3.5]);grid(ax,'on');
haps_export_figure(f,outDir,'fig04d_thermal_robustness',T);
out=struct('output_dir',outDir);
end
