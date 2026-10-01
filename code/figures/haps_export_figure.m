function haps_export_figure(fig,outputDir,name,values)
% HAPS_EXPORT_FIGURE Export a numerical panel and its exact plotted values.
prefix=fullfile(outputDir,char(name));
if nargin>=4&&istable(values),writetable(values,[prefix '_values.csv']);end
cleanup=onCleanup(@()close(fig));
savefig(fig,[prefix '.fig']);
exportgraphics(fig,[prefix '.png'],'Resolution',300);
exportgraphics(fig,[prefix '.pdf'],'ContentType','vector');
end
