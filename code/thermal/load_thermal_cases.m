function cases = load_thermal_cases(study,caseIDs)
% LOAD_THERMAL_CASES Explicit absolute parameters; never apply duct scale twice.
p=haps_paths;cases=readtable(fullfile(p.processed,'thermal_cases.csv'),'TextType','string');
if nargin>=1&&strlength(string(study))>0&&string(study)~="all"
    cases=cases(string(cases.study)==string(study),:);
end
if nargin>=2&&~isempty(caseIDs)
    caseIDs=string(caseIDs);caseIDs=caseIDs(:);[tf,idx]=ismember(caseIDs,string(cases.case_id));
    if ~all(tf),error('HAPS:ThermalCase','Unknown case ID(s): %s.',strjoin(caseIDs(~tf),', '));end
    cases=cases(idx,:);
end
if isempty(cases),error('HAPS:ThermalCase','No cases selected.');end
assert(all(abs(cases.G_wall-cases.k_wall.*cases.A_wall./cases.t_wall)<1e-6), ...
    'HAPS:WallParameters','Inconsistent wall conductance.');
assert(all(cases.A_res1<=cases.A_pipe&cases.A_res3<=cases.A_pipe), ...
    'HAPS:FlowParameters','Restriction area exceeds the pipe area.');
end
