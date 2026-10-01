function T = record_environment(outputFile)
% RECORD_ENVIRONMENT Record the actual MATLAB/product environment of a run.
% This reports installed products, not a certified minimum dependency list.
v=ver; names=string({v.Name}).'; versions=string({v.Version}).';
releases=string({v.Release}).';
T=table(names,versions,releases,'VariableNames',{'product','version','release'});
if nargin>0 && strlength(string(outputFile))>0
    writetable(T,haps_new_output_file(outputFile));
end
end
