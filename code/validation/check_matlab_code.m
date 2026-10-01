function report = check_matlab_code()
% CHECK_MATLAB_CODE Run the actual MATLAB Code Analyzer on migrated functions.
% This complements (does not replace) validate_release and execution tests.
paths=haps_paths;items=dir(fullfile(paths.root,'code','**','*.m'));
items=[items;dir(fullfile(paths.root,'*.m'))];
rows=cell(0,3);
for i=1:numel(items)
    f=fullfile(items(i).folder,items(i).name);messages=checkcode(f);
    for j=1:numel(messages)
        rows(end+1,:)={string(items(i).name),double(messages(j).line),string(messages(j).message)}; %#ok<AGROW>
    end
end
report=cell2table(rows,'VariableNames',{'file','line','message'});
disp(report);
end
