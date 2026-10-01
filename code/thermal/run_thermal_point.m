function row = run_thermal_point(c,rpm,stage,traceDir)
% RUN_THERMAL_POINT One simulation with complete input and diagnostic logging.
% A solver failure is never relabeled as physical thermal infeasibility.
% Parameters are temporary SimulationInput overrides, not base-workspace writes.
if nargin<3,stage="point";end
if nargin<4,traceDir='';end
validateattributes(rpm,{'numeric'},{'scalar','finite','positive'});
if istable(c),c=table2struct(c);end
[~,model]=fileparts(char(c.model_file));
row=struct('case_id',string(c.case_id),'study',string(c.study),'rpm',rpm, ...
    'stage',string(stage),'sim_success',false,'feasible',false,'converged',false, ...
    'status',"not_run",'error_identifier',"",'error_message',"", ...
    'requested_stop_time_s',c.stop_time_s,'actual_stop_time_s',NaN, ...
    'wallclock_seconds',NaN,'server_mean_tail_K',NaN,'chamber_mean_tail_K',NaN, ...
    'radiator_mean_tail_K',NaN,'server_slope_tail_K_s',NaN,'chamber_slope_tail_K_s',NaN, ...
    'server_delta_tail_K',NaN,'chamber_delta_tail_K',NaN, ...
    'server_margin_K',NaN,'chamber_margin_K',NaN,'vdot_m3_s',NaN, ...
    'mdot_kg_s',NaN,'dp_total_Pa',NaN,'fan_shaft_power_W',NaN, ...
    'fan_electrical_power_W',NaN,'fan_overhead_percent',NaN,'above_preferred_rpm',rpm>5000);
t0=tic;
try
    simIn=Simulink.SimulationInput(model);
    names={'Q_server','P_air_internal','T_air_internal','T_ambient','h2','A2', ...
        'h1','A1','L_pipe','A_pipe','D_h_pipe','A_res1','A_res3','q_fan_nom', ...
        'dp_fan_nom','eta_fan_nom','dp_fan_max0','q_fan_max0','w_fan_ref_rpm', ...
        'Q_solar','epsilon_rad','k_rad','A_rad','T_sky','G_wall','A_wall','t_wall', ...
        'k_wall','m_HX','cp_HX','T_HX0'};
    for i=1:numel(names),simIn=simIn.setVariable(names{i},double(c.(names{i})));end
    simIn=simIn.setVariable('w_fan_cmd_rpm',rpm);
    simIn=simIn.setModelParameter('StopTime',sprintf('%.17g',c.stop_time_s), ...
        'ReturnWorkspaceOutputs','on','SignalLogging','on','SignalLoggingName','logsout', ...
        'CaptureErrors','off');
    simOut=sim(simIn);
    logs=simOut.logsout;
    names={'server_T','chamber_T','radiator_T','P_delta_total','P_delta_pipe', ...
        'T_delta_pipe','v_dot','m_dot','tau_fan','omega_fan','P_fan_shaft'};
    stats=cell(size(names));
    for i=1:numel(names)
        element=logs.getElement(names{i});ts=element.Values;
        stats{i}=thermal_tail_statistics(ts,c.tail_sec);
        if ~isempty(traceDir)
            if ~isfolder(traceDir),mkdir(traceDir);end
            signal=table(double(ts.Time(:)),double(reshape(ts.Data,[],1)), ...
                'VariableNames',{'time_s','value'});
            writetable(signal,fullfile(traceDir,[names{i} '.csv']));
        end
    end
    a=stats{1};b=stats{2};rad=stats{3};dp=stats{4};vd=stats{7};md=stats{8};shaft=stats{11};
    row.actual_stop_time_s=a.actual_stop_time_s;row.server_mean_tail_K=a.mean_tail;
    row.chamber_mean_tail_K=b.mean_tail;row.radiator_mean_tail_K=rad.mean_tail;
    row.server_slope_tail_K_s=a.slope_tail;row.chamber_slope_tail_K_s=b.slope_tail;
    row.server_delta_tail_K=a.delta_tail;row.chamber_delta_tail_K=b.delta_tail;
    row.server_margin_K=c.T_server_limit-a.mean_tail;row.chamber_margin_K=c.T_chamber_limit-b.mean_tail;
    row.vdot_m3_s=vd.mean_tail;row.mdot_kg_s=md.mean_tail;row.dp_total_Pa=dp.mean_tail;
    row.fan_shaft_power_W=abs(shaft.mean_tail);
    row.fan_electrical_power_W=abs(shaft.mean_tail)/c.eta_motor_elec;
    row.fan_overhead_percent=100*row.fan_electrical_power_W/c.Q_server;
    completed=abs(a.actual_stop_time_s-c.stop_time_s)<=max(1e-6,1e-8*c.stop_time_s);
    row.sim_success=completed;
    row.converged=completed&&abs(a.slope_tail)<1e-3&&abs(b.slope_tail)<1e-3&& ...
        abs(a.delta_tail)<.5&&abs(b.delta_tail)<.5&&a.actual_stop_time_s>=c.tail_sec;
    row.feasible=row.converged&&row.server_margin_K>=0&&row.chamber_margin_K>=0;
    if ~completed
        row.status = "incomplete_simulation";
    elseif ~row.converged
        row.status = "not_converged";
    elseif row.feasible
        row.status = "feasible";
    else
        row.status = "temperature_limit_exceeded";
    end
catch ME
    row.status="simulation_or_signal_error";row.error_identifier=string(ME.identifier);
    row.error_message=string(ME.message);
    if ~isempty(traceDir)
        if ~isfolder(traceDir),mkdir(traceDir);end
        fid=fopen(fullfile(traceDir,'error_report.txt'),'w');
        if fid>=0,fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off'));fclose(fid);end
    end
end
row.wallclock_seconds=toc(t0);
fprintf('%s | %g rpm | %s | fan %.6g W | %.1f s elapsed\n', ...
    row.case_id,rpm,row.status,row.fan_electrical_power_W,row.wallclock_seconds);
end
