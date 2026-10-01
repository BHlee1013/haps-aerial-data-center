function report = validate_stage2(varargin)
% VALIDATE_STAGE2 Fast structural/source checks; does not execute Simulink.
% Code Analyzer is a separate diagnostic, not a source of numerical pass/fail.

p = inputParser;
addParameter(p,'OutputFile','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});

p0 = haps_paths;
maxChecks = 128;
checks = strings(maxChecks,1);
ok = false(maxChecks,1);
nChecks = 0;

C = load_thermal_cases('all');
studies = ["map","duct","robustness","highload_a","highload_b","highload_c","highload_c2"];
counts = [957,14,22,3,18,60,84];
for i = 1:numel(studies)
    add("thermal_count_" + studies(i),sum(C.study==studies(i))==counts(i));
end
add("unique_thermal_case_ids",height(C)==1158 && numel(unique(C.case_id))==height(C));
add("thermal_wall_relation",all(abs(C.G_wall-C.k_wall.*C.A_wall./C.t_wall)<1e-6));
add("thermal_radiation_relation",all(abs(C.k_rad-C.epsilon_rad*5.670374419e-8)<1e-20));
add("thermal_durations",all(ismember(C.stop_time_s,[5000,10000])));

ref = C(C.case_id=="robustness_0001",:);
add("selected_duct_not_double_scaled",height(ref)==1 && abs(ref.A_pipe-.015)<1e-14 && ...
    abs(ref.A_res1-.0135)<1e-14 && abs(ref.A_res3-.009)<1e-14 && ref.Q_server==1100);

% Read the model manifest with an explicit line parser. This avoids locale-
% dependent CSV delimiter inference (observed on a Korean Windows MATLAB host).
manifestFile = fullfile(p0.root,'models','simscape','model_manifest.csv');
[modelFiles,modelHashes] = read_model_manifest(manifestFile);
for i = 1:numel(modelFiles)
    modelPath = fullfile(p0.root,'models','simscape',modelFiles(i));
    add("model_sha256_" + modelFiles(i),strcmpi(haps_sha256(modelPath),modelHashes(i)));
end

T = readtable(fullfile(p0.processed,'thermal_smoke_checkpoints.csv'), ...
    'VariableNamingRule','preserve');
add("thermal_adjacent_checkpoints",isequal(T.rpm,[2650;2675]) && ...
    isequal(T.expected_feasible,[0;1]));
add("thermal_reference_fan",abs(T.fan_electrical_power_W(2)-8.6344431797461)<1e-12);

% Explicit inversion semantics and measured-range caps.
add("crossing_linear",abs(serving_crossing([1;5;10],[10;20;40],30,'linear')-7.5)<1e-14);
add("crossing_lower_step",serving_crossing([1;5;10],[10;20;40],30,'lower_step')==5);
add("crossing_log_linear",abs(serving_crossing([1;5;10],[10;20;40],30,'log_linear')-sqrt(50))<1e-13);
add("crossing_inverse_pchip",abs(serving_crossing([1;5;10],[10;20;40],30,'pchip')- ...
    pchip([10;20;40],[1;5;10],30))<1e-13);
add("crossing_infeasible",serving_crossing([1;5],[20;30],10,'linear')==0);
add("crossing_capped",serving_crossing([1;5],[20;30],50,'linear')==5);

unit = test_workload_helpers();
nUnit = height(unit);
if nChecks + nUnit > maxChecks
    error('HAPS:Stage2Validation','Internal validation check capacity exceeded.');
end
idx = nChecks + (1:nUnit);
checks(idx) = string(unit.check);
ok(idx) = logical(unit.passed);
nChecks = nChecks + nUnit;

table6 = validate_supplementary_table6();
nTable6 = height(table6);
if nChecks + nTable6 > maxChecks
    error('HAPS:Stage2Validation','Internal validation check capacity exceeded.');
end
idx = nChecks + (1:nTable6);
checks(idx) = string(table6.check);
ok(idx) = logical(table6.passed);
nChecks = nChecks + nTable6;

protocol = readtable(fullfile(p0.processed,'mc_seed_protocol.csv'), ...
    'TextType','string','VariableNamingRule','preserve');
add("mc_protocol_anchors",height(protocol)==2 && ...
    all(ismember(protocol.fixed_lower_anchor_N,[5806;920])));

checks = checks(1:nChecks);
ok = ok(1:nChecks);
report = table(checks,ok,'VariableNames',{'check','passed'});
if strlength(string(p.Results.OutputFile)) > 0
    writetable(report,haps_new_output_file(p.Results.OutputFile));
end
if ~all(report.passed)
    disp(report(~report.passed,:));
    error('HAPS:Stage2Validation','Stage-2 checks failed.');
end
fprintf('Passed %d Stage-2 structural/unit checks; no thermal simulation run.\n',height(report));

    function add(name,value)
        nChecks = nChecks + 1;
        if nChecks > maxChecks
            error('HAPS:Stage2Validation','Internal validation check capacity exceeded.');
        end
        checks(nChecks) = string(name);
        ok(nChecks) = isscalar(value) && logical(value);
    end
end
