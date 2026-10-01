function result = thermal_tail_statistics(ts,tailSeconds)
% THERMAL_TAIL_STATISTICS Preserve the source sample-mean tail estimator.
% The mean is over solver output samples, not a newly introduced time integral.
t=double(ts.Time(:));y=double(squeeze(ts.Data));y=y(:);
if numel(y)~=numel(t)||numel(t)<2||any(~isfinite(t)|~isfinite(y))||any(diff(t)<0)
    error('HAPS:ThermalSignal','Require finite scalar timeseries with nondecreasing time.');
end
idx=t>=t(end)-tailSeconds;tt=t(idx);yy=y(idx);
result=struct('final',y(end),'mean_tail',mean(yy),'max',max(y), ...
    'min',min(y),'delta_tail',yy(end)-yy(1),'slope_tail',NaN, ...
    'actual_stop_time_s',t(end),'tail_sample_count',numel(tt));
if numel(tt)>=2&&tt(end)>tt(1)
    coef=polyfit(tt,yy,1);result.slope_tail=coef(1);
end
end
