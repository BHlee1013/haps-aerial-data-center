function [Pplatform,instanceP,partition] = exact_static_balanced_overload_probability(NkTotal,alpha,cmax,m)
% EXACT_STATIC_BALANCED_OVERLOAD_PROBABILITY
% Exact-under-model platform overload probability for static balanced
% request assignment across m serving instances.
%
% Each workload-type population N_k is divided as evenly as possible across
% the m instances. For reproducibility and monotonicity, the first r_k
% instances receive one additional type-k user when mod(N_k,m)=r_k.
% Platform failure occurs if ANY serving instance overloads.
%
% Because the partitions contain disjoint user-equivalent populations and
% the manuscript assumes independent user activity, the per-instance
% overload events are independent under this model:
%
%   P_platform = 1 - prod_i (1 - P_i).

validateattributes(NkTotal,{'numeric'},{'real','finite','vector','numel',5,'integer','nonnegative'},mfilename,'NkTotal');
validateattributes(m,{'numeric'},{'real','finite','scalar','integer','positive'},mfilename,'m');
NkTotal = double(NkTotal(:));
alpha = double(alpha(:));
cmax = double(cmax(:));
m = round(m);

if numel(NkTotal)~=5 || numel(alpha)~=5 || numel(cmax)~=5
    error('NkTotal, alpha, and cmax must each contain five elements.');
end
if m<1
    error('m must be a positive integer.');
end

partition = zeros(5,m);
for k=1:5
    b = floor(NkTotal(k)/m);
    r = mod(NkTotal(k),m);
    partition(k,:) = b;
    if r>0
        partition(k,1:r) = partition(k,1:r)+1;
    end
end

if any(sum(partition,2)~=NkTotal)
    error('Static partition does not preserve the total population by type.');
end
if any(max(partition,[],2)-min(partition,[],2)>1)
    error('Static partition is not balanced within one user per type.');
end

instanceP = zeros(m,1);
for i=1:m
    instanceP(i) = exact_binomial_overload_probability(partition(:,i),alpha,cmax);
end

if any(instanceP>=1)
    Pplatform = 1;
else
    % Numerically stable complement product.
    Pplatform = 1-exp(sum(log1p(-instanceP)));
end
Pplatform = min(1,max(0,Pplatform));
end
