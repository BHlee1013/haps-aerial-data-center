function report = validate_supplementary_table6()
% VALIDATE_SUPPLEMENTARY_TABLE6 Check the manuscript-defined 7-row C2 envelope.
% No simulation is run. The selected rows are checked against the archived
% 84-case C2 summary and the wider 10-row best-by-UA exploratory table.

p0 = haps_paths;
base = fullfile(p0.reference,'thermal','highload_c2');
best = readtable(haps_require_file(fullfile(base,'C2_best_by_UA.csv')), ...
    'TextType','string','VariableNamingRule','preserve');
summary = readtable(haps_require_file(fullfile(base,'C2_summary.csv')), ...
    'TextType','string','VariableNamingRule','preserve');

uaWanted = [300;350;400;500;600;750;1000];
checks = strings(0,1);
passed = false(0,1);

add("table6_source_has_wider_archive", ...
    isequal(double(best.UA_ext_W_K),[175;200;250;uaWanted]));

selected = build_supplementary_table6(fullfile(p0.reference,'thermal'));
add("table6_exactly_seven_rows",height(selected)==7);
add("table6_ua_order",isequal(double(selected.UA_ext_W_K),uaWanted));
add("table6_qit_2550W",all(selected.Q_server_W==2550));
add("table6_rows_feasible",all(selected.has_feasible_point==1));

bestMatchesSummary = true;
for k = 1:numel(uaWanted)
    candidate = summary(summary.Q_server_W==2550 & ...
        summary.UA_ext_W_K==uaWanted(k) & summary.has_feasible_point==1 & ...
        isfinite(summary.fan_overhead_percent),:);
    if isempty(candidate)
        bestMatchesSummary = false;
        break;
    end
    [~,idx] = min(candidate.fan_overhead_percent);
    row = candidate(idx,:);
    bestMatchesSummary = bestMatchesSummary && ...
        abs(row.min_feasible_rpm-selected.min_feasible_rpm(k))<1e-12 && ...
        abs(row.min_fan_elec_power_W-selected.min_fan_elec_power_W(k))<1e-10 && ...
        abs(row.fan_overhead_percent-selected.fan_overhead_percent(k))<1e-12 && ...
        abs(row.A2_m2-selected.A2_m2(k))<1e-12;
end
add("table6_best_by_ua_matches_c2_summary",bestMatchesSummary);

report = table(checks,passed,'VariableNames',{'check','passed'});
if ~all(report.passed)
    disp(report(~report.passed,:));
    error('HAPS:SupplementaryTable6Validation', ...
        'Supplementary Table 6 source checks failed.');
end

    function add(name,value)
        checks(end+1,1) = string(name);
        passed(end+1,1) = isscalar(value) && logical(value);
    end
end
