function c = serving_crossing(x,y,limit,method)
% SERVING_CROSSING Reviewed SLO crossing rule; no concurrency extrapolation.
% PCHIP interpolates the INVERSE latency->concurrency relation, grouping equal
% monotonized latencies by their largest concurrency (the source convention).
x=double(x(:));y=double(y(:));method=lower(string(method));
validateattributes(limit,{'numeric'},{'scalar','finite','positive'});
if isempty(x)||numel(x)~=numel(y)||any(~isfinite(x)|x<=0)||any(~isfinite(y)|y<0)
    error('HAPS:LatencyCurve','Require finite nonnegative latency and positive concurrency.');
end
[x,i]=sort(x);y=cummax(y(i));
if any(diff(x)<=0),error('HAPS:DuplicateConcurrency','Concurrency must be unique.');end
if y(1)>limit,c=0;return;end
if y(end)<=limit,c=x(end);return;end
j=find(y>limit,1);i=j-1;
switch method
    case 'lower_step',c=x(i);
    case 'linear',c=x(i)+(limit-y(i))*(x(j)-x(i))/(y(j)-y(i));
    case 'log_linear',c=exp(log(x(i))+(limit-y(i))*(log(x(j))-log(x(i)))/(y(j)-y(i)));
    case 'pchip'
        [uy,~,g]=unique(y);xx=accumarray(g,x,[],@max);
        c=pchip(uy,xx,limit);c=max(min(c,x(end)),x(1));
    otherwise,error('HAPS:Interpolation','Unknown interpolation method: %s.',method);
end
end
