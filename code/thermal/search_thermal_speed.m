function [points,summary] = search_thermal_speed(c,caseOutputDir)
% SEARCH_THERMAL_SPEED Bracket/refine on the source 25-rpm grid.
% Search limits: 750 rpm minimum, 5000 preferred, 12000 hard cap. Unlike old
% scripts, an unresolved simulation/nonconvergence CANNOT advance a bound.
% A resolved adjacent crossing relies on the source monotone-search premise;
% it does not prove feasibility/infeasibility at every untested fan speed.
if istable(c),c=table2struct(c);end
rows=cell(0,1);low=NaN;high=NaN;
probes=[750 1000 1500 2000 2500 2675 3000 4000 5000];
for rpm=probes
    r=evaluate(rpm,'probe');
    if r.feasible,high=rpm;break;end
    if r.converged,low=rpm;end
end
if isnan(high)
    rpm=probes(end);
    while rpm<12000
        rpm=min(12000,25*ceil(max(rpm*1.35,rpm+750)/25));r=evaluate(rpm,'expand');
        if r.feasible,high=rpm;break;end
        if r.converged,low=rpm;end
    end
end
resolved=false;leftCensored=false;
if isnan(high)
    status="no_feasible_point_found_in_tested_range";
elseif high==750
    status="left_censored_at_minimum_rpm";leftCensored=true;
elseif isnan(low)
    status="feasible_candidate_with_unresolved_lower_bound";
else
    status="refining";
    while high-low>25
        rpm=25*floor(((low+high)/2)/25);rpm=max(low+25,min(high-25,rpm));
        r=evaluate(rpm,'refine');
        if ~r.sim_success || ~r.converged
            status = "indeterminate_refinement";
            break;
        elseif r.feasible
            high = rpm;
        else
            low = rpm;
        end
    end
    if high-low==25
        resolved=true;status="resolved_within_preferred_rpm";
        if high>5000,status="resolved_high_rpm_model_extrapolation";end
    end
end
points=struct2table(vertcat(rows{:}));
minRPM=NaN;fan=NaN;server=NaN;chamber=NaN;
if resolved
    minRPM=high;i=find(points.rpm==high&points.feasible,1,'last');
    fan=points.fan_electrical_power_W(i);server=points.server_mean_tail_K(i);chamber=points.chamber_mean_tail_K(i);
end
summary=table(string(c.case_id),string(c.study),c.Q_server,c.A2*c.h2,c.A1,c.duct_area_scale, ...
    resolved,leftCensored,any(points.feasible),minRPM,high,low,fan,100*fan/c.Q_server, ...
    server,chamber,string(status),height(points),sum(~points.sim_success),sum(points.sim_success&~points.converged), ...
    'VariableNames',{'case_id','study','Q_server_W','UA_ext_W_K','A1_m2','duct_scale', ...
    'threshold_resolved','left_censored','has_tested_feasible_point','min_feasible_rpm', ...
    'best_tested_feasible_rpm','resolved_infeasible_lower_rpm','fan_electrical_power_W', ...
    'fan_overhead_percent','server_mean_tail_K','chamber_mean_tail_K','search_status', ...
    'num_simulations','num_simulation_errors','num_nonconverged'});
    function r=evaluate(rpm,stage)
        for n=1:numel(rows)
            if rows{n}.rpm==rpm,r=rows{n};return;end
        end
        r=run_thermal_point(c,rpm,stage,'');rows{end+1,1}=r;
        writetable(struct2table(vertcat(rows{:})),fullfile(caseOutputDir,'point_results.csv'));
    end
end
