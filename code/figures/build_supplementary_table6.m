function T6paper = build_supplementary_table6(thermalDir)
% BUILD_SUPPLEMENTARY_TABLE6 Select the seven manuscript Table 6 UA values.
% The wider C2_best_by_UA.csv exploratory archive is left unchanged.

source = fullfile(thermalDir,'highload_c2','C2_best_by_UA.csv');
T6 = readtable(haps_require_file(source), ...
    'TextType','string','VariableNamingRule','preserve');
required = {'Q_server_W','UA_ext_W_K','has_feasible_point', ...
    'min_feasible_rpm','min_fan_elec_power_W','fan_overhead_percent','A2_m2'};
if ~all(ismember(required,T6.Properties.VariableNames))
    error('HAPS:SupplementaryTable6','C2_best_by_UA.csv has an unexpected schema.');
end

uaWanted = [300;350;400;500;600;750;1000];
rows = zeros(numel(uaWanted),1);
for k = 1:numel(uaWanted)
    hit = find(T6.Q_server_W==2550 & T6.UA_ext_W_K==uaWanted(k));
    if numel(hit) ~= 1
        error('HAPS:SupplementaryTable6', ...
            'Expected exactly one 2.55-kW best-by-UA row for UA_ext=%g W/K.',uaWanted(k));
    end
    rows(k) = hit;
end
T6paper = T6(rows,:);
if height(T6paper)~=7 || ~isequal(double(T6paper.UA_ext_W_K),uaWanted) || ...
        any(T6paper.has_feasible_point~=1)
    error('HAPS:SupplementaryTable6','Manuscript Table 6 selection failed validation.');
end
end
