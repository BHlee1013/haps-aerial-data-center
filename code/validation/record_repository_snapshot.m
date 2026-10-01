function T = record_repository_snapshot(outputFile)
% RECORD_REPOSITORY_SNAPSHOT Hash code, model and processed-input files in use.
% Generated outputs and raw data are not scanned. No local absolute paths are
% written to the table. This documents file identity, not runtime correctness.
p=haps_paths;items=[dir(fullfile(p.root,'*.m'));dir(fullfile(p.root,'code','**','*.m')); ...
    dir(fullfile(p.root,'models','simscape','*.slx'));dir(fullfile(p.processed,'*.csv'))];
file=strings(numel(items),1);sha256=file;bytes=zeros(numel(items),1);
for i=1:numel(items)
    path=fullfile(items(i).folder,items(i).name);file(i)=replace(string(path(numel(p.root)+2:end)),'\','/');
    sha256(i)=string(haps_sha256(path));bytes(i)=items(i).bytes;
end
T=table(file,bytes,sha256);writetable(T,haps_new_output_file(outputFile));
end
