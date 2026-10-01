function [P,diagOut] = exact_binomial_overload_probability(Nk,alpha,cmax)
% EXACT_BINOMIAL_OVERLOAD_PROBABILITY
% Deterministically evaluates
%
%   P_OL = P( sum_k n_k/Cmax_k > 1 )
%
% for five independent workload classes A-E with
%
%   n_k ~ Binomial(N_k, alpha_k).
%
% The calculation contains no Monte-Carlo sampling. States in which any
% single workload class already exceeds its own capacity are handled by an
% exact complement probability. The remaining safe-support states are
% evaluated by a 2+2+1 decomposition. One pair distribution is sorted once,
% and its strict upper tail is queried by binary search for every state of
% the other pair and the singleton class.
%
% Inputs
%   Nk     : 5x1 non-negative integer population vector [A..E]
%   alpha  : 5x1 activity probabilities in (0,1]
%   cmax   : 5x1 positive type-specific capacities
%
% Output
%   P      : exact-under-model overload probability, up to floating-point
%            arithmetic
%   diagOut: diagnostic structure describing the chosen decomposition
%
% IMPORTANT
%   "Exact" means exact under the assumed independent-Binomial activity
%   model. It does not remove uncertainty in alpha_k, p_k, Cmax_k, or the
%   independence/model assumptions.

validateattributes(Nk,{'numeric'},{'real','finite','vector','numel',5,'integer','nonnegative'},mfilename,'Nk');
Nk = double(Nk(:));
alpha = double(alpha(:));
cmax = double(cmax(:));

if numel(Nk)~=5 || numel(alpha)~=5 || numel(cmax)~=5
    error('Nk, alpha, and cmax must each contain five elements (A-E).');
end
if any(Nk<0) || any(~isfinite(Nk))
    error('Nk must contain finite non-negative integer populations.');
end
if any(~isfinite(alpha) | alpha<=0 | alpha>1)
    error('alpha must contain finite values in (0,1].');
end
if any(~isfinite(cmax) | cmax<=0)
    error('cmax must contain finite positive capacities.');
end
if exist('binopdf','file')~=2 || exist('binocdf','file')~=2
    error(['Statistics and Machine Learning Toolbox is required ' ...
           '(binopdf/binocdf).']);
end

K = 5;

% Largest integer active count that does not exceed the capacity by itself.
% The small tolerance prevents an integer-valued capacity represented as
% 249.99999999999997 from being floored incorrectly.
cap = zeros(K,1);
pWithin = zeros(K,1);
x = cell(K,1);
pmf = cell(K,1);

for k = 1:K
    tolC = 64*eps(max(1,abs(cmax(k))));
    cap(k) = min(Nk(k),floor(cmax(k)+tolC));
    pWithin(k) = binocdf(cap(k),Nk(k),alpha(k));

    xx = (0:cap(k)).';
    pp = binopdf(xx,Nk(k),alpha(k));

    % Dropping entries that are already exactly zero in IEEE double does
    % not alter the floating-point result and can greatly reduce state size
    % for large-N / small-alpha cases.
    keep = (pp>0);
    if ~any(keep)
        % This should not occur for a valid binomial distribution, but retain
        % the mode explicitly as a numerical fallback.
        modeX = min(cap(k),floor((Nk(k)+1)*alpha(k)));
        xx = modeX;
        pp = binopdf(modeX,Nk(k),alpha(k));
    else
        xx = xx(keep);
        pp = pp(keep);
    end

    x{k} = xx;
    pmf{k} = pp;
end

% Any type count above its individual safe cap is certainly overloaded.
P_individual_over = 1 - prod(pWithin);

% Choose the 2+2+1 decomposition that minimizes the number of strict-tail
% queries. For a chosen singleton, the smaller pair is enumerated as the
% "other" pair and the larger pair is sorted once as the query distribution.
bestCost = inf;
bestSingleton = NaN;
bestQueryPair = [];
bestOtherPair = [];

for s = 1:K
    rem = setdiff(1:K,s,'stable');
    pairings = {
        rem([1 2]), rem([3 4]);
        rem([1 3]), rem([2 4]);
        rem([1 4]), rem([2 3])};

    for r = 1:size(pairings,1)
        p1 = pairings{r,1};
        p2 = pairings{r,2};
        n1 = numel(x{p1(1)})*numel(x{p1(2)});
        n2 = numel(x{p2(1)})*numel(x{p2(2)});

        if n1>=n2
            qPair = p1;
            oPair = p2;
            nOther = n2;
        else
            qPair = p2;
            oPair = p1;
            nOther = n1;
        end

        cost = numel(x{s})*nOther;
        if cost < bestCost
            bestCost = cost;
            bestSingleton = s;
            bestQueryPair = qPair;
            bestOtherPair = oPair;
        end
    end
end

s = bestSingleton;
qPair = bestQueryPair;
oPair = bestOtherPair;

% Query-pair load/probability states.
[lq,pq] = makePairStatesLocal(x{qPair(1)},pmf{qPair(1)},cmax(qPair(1)), ...
                              x{qPair(2)},pmf{qPair(2)},cmax(qPair(2)));
[lq,ord] = sort(lq,'ascend');
pq = pq(ord);
cdfQ = cumsum(pq);
totalQ = cdfQ(end);

% Other-pair states.
[lo,po] = makePairStatesLocal(x{oPair(1)},pmf{oPair(1)},cmax(oPair(1)), ...
                              x{oPair(2)},pmf{oPair(2)},cmax(oPair(2)));

P_safe_joint_over = 0;
xs = x{s};
ps = pmf{s};

for is = 1:numel(xs)
    if ps(is)==0
        continue;
    end

    singletonLoad = xs(is)/cmax(s);
    thresholdQ = 1 - singletonLoad - lo;

    % We need P(L_query > thresholdQ) because overload is strictly B>1.
    tailQ = strictUpperTailFromSortedLocal(lq,cdfQ,totalQ,thresholdQ);
    P_safe_joint_over = P_safe_joint_over + ps(is)*sum(po.*tailQ);
end

P = P_individual_over + P_safe_joint_over;
P = min(1,max(0,P));

diagOut = struct();
diagOut.safe_caps = cap;
diagOut.within_cap_probability_by_type = pWithin;
diagOut.individual_overload_probability = P_individual_over;
diagOut.safe_joint_overload_probability = P_safe_joint_over;
diagOut.singleton_type_index = s;
diagOut.query_pair_indices = qPair;
diagOut.other_pair_indices = oPair;
diagOut.query_pair_states = numel(lq);
diagOut.other_pair_states = numel(lo);
diagOut.singleton_states = numel(xs);
diagOut.estimated_tail_queries = bestCost;

end

function [loadVec,probVec] = makePairStatesLocal(x1,p1,c1,x2,p2,c2)
% Cartesian product of two truncated binomial supports.
loadMat = x1./c1 + (x2./c2).';
probMat = p1 * p2.';
loadVec = loadMat(:);
probVec = probMat(:);
end

function tail = strictUpperTailFromSortedLocal(sortedLoad,cdfProb,totalProb,t)
% For every threshold t_j, returns sum(prob(sortedLoad > t_j)).
% A vectorized upper-bound binary search finds the number of sorted loads
% <= t_j. A small positive floating tolerance prevents a mathematically
% equal total load from being classified as a strict overload.

t = double(t(:));
fpTol = 128*eps(max(1,abs(t)));
tAdj = t + fpTol;

n = numel(sortedLoad);
lo = zeros(size(tAdj));       % number known <= threshold
hi = n*ones(size(tAdj));      % upper bound on number <= threshold

active = (lo<hi);
while any(active)
    idx = find(active);
    mid = ceil((lo(idx)+hi(idx))/2);
    v = sortedLoad(mid);
    cond = (v<=tAdj(idx));

    idxTrue = idx(cond);
    idxFalse = idx(~cond);
    lo(idxTrue) = mid(cond);
    hi(idxFalse) = mid(~cond)-1;
    active = (lo<hi);
end

nLE = lo;
tail = totalProb*ones(size(tAdj));
mask = nLE>0;
tail(mask) = totalProb - cdfProb(nLE(mask));

tail = max(0,min(totalProb,tail));
end
