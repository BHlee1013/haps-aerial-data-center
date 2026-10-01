function [distanceType,membership,distanceSquared] = classify_workload_pairs(T,definitions)
% CLASSIFY_WORKLOAD_PAIRS Standardized log1p distances and independent windows.
% Population standard deviations (normalization N, not N-1) are computed on
% the entire tau-filtered pair set. Ties select the first type in A-E order.
if nargin<2
    p=haps_paths;definitions=readtable(fullfile(p.processed,'workload_type_definitions.csv'),'TextType','string');
end
[tf,ii]=ismember(["A";"B";"C";"D";"E"],string(definitions.Type));
if ~all(tf)||height(definitions)~=5,error('HAPS:TypeDefinition','Require five unique A-E types.');end
definitions=definitions(ii,:);
x=log1p(double(T.input_tokens));y=log1p(double(T.output_tokens));
sx=std(x,1);sy=std(y,1);
if ~(isfinite(sx)&&sx>0),sx=1;end
if ~(isfinite(sy)&&sy>0),sy=1;end
cx=log1p(definitions.center_input_tokens);cy=log1p(definitions.center_output_tokens);
distanceSquared=zeros(height(T),5);membership=false(height(T),5);
for k=1:5
    distanceSquared(:,k)=((x-cx(k))/sx).^2+((y-cy(k))/sy).^2;
    membership(:,k)=T.input_tokens>=definitions.request_min(k)& ...
        T.input_tokens<=definitions.request_max(k)& ...
        T.output_tokens>=definitions.response_min(k)&T.output_tokens<=definitions.response_max(k);
end
[~,distanceType]=min(distanceSquared,[],2);
end
