function out = find_exact_reliability_threshold(pk,alpha,cmax,varargin)
% FIND_EXACT_RELIABILITY_THRESHOLD
% Finds the largest integer population N satisfying
%
%   P_OL(N) <= ReliabilityThreshold
%
% using exact_binomial_overload_probability and the sequential-deficit
% monotonic population-allocation rule used in the manuscript pipeline.
%
% This same function is used for both single-instance and ideal pooled
% platform calculations. For an m-instance pooled platform, pass m*cmax.

validateattributes(pk,{'numeric'},{'real','finite','vector','numel',5,'nonnegative'},mfilename,'pk');
validateattributes(alpha,{'numeric'},{'real','finite','vector','numel',5,'positive','<=',1},mfilename,'alpha');
if sum(pk)<=0, error('HAPS:InvalidMixture','The workload shares must have positive total.'); end

p = inputParser;
addParameter(p,'ReliabilityThreshold',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);
addParameter(p,'InitialGuess',NaN,@(x)isnumeric(x)&&isscalar(x));
addParameter(p,'NeighborhoodHalfWidth',2,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'Verbose',false,@(x)islogical(x)||isnumeric(x));
addParameter(p,'Label','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
opt = p.Results;

pk = double(pk(:));
alpha = double(alpha(:));
cmax = double(cmax(:));

if numel(pk)~=5 || numel(alpha)~=5 || numel(cmax)~=5
    error('pk, alpha, and cmax must each contain five elements.');
end
if any(cmax<=0 | ~isfinite(cmax))
    error('All capacities must be finite and positive.');
end
pk = pk/sum(pk);
q = (pk./alpha); q = q/sum(q);

Cmix = 1/sum(pk./cmax);
Nharm = Cmix*sum(pk./alpha);
threshold = double(opt.ReliabilityThreshold);
verbose = logical(opt.Verbose);
label = string(opt.Label);

% Initial bracket. A supplied old/expected threshold is used only as a
% numerical starting point; the exact search automatically expands if the
% true crossing lies outside it.
if isfinite(opt.InitialGuess) && opt.InitialGuess>0
    Nlo = max(0,floor(0.75*opt.InitialGuess));
    Nhi = max(Nlo+1,ceil(1.25*opt.InitialGuess));
else
    Nlo = max(0,floor(0.25*Nharm));
    Nhi = max(Nlo+1,ceil(Nharm));
end

maxExpand = 12;
for attempt = 1:maxExpand
    alloc = buildAllocationPathLocal(Nhi,q);
    Plo = evalAtNLocal(Nlo,alloc,alpha,cmax);
    Phi = evalAtNLocal(Nhi,alloc,alpha,cmax);

    if verbose
        fprintf('[%s] bracket %d: N=%d -> %.6f%%, N=%d -> %.6f%%\n', ...
            label,attempt,Nlo,100*Plo,Nhi,100*Phi);
    end

    if Plo<=threshold && Phi>threshold
        break;
    end
    if Plo>threshold
        NloNew = max(0,floor(0.70*Nlo));
        if NloNew==Nlo && Nlo>0, NloNew=Nlo-1; end
        Nlo = NloNew;
    end
    if Phi<=threshold
        Nhi = max(Nhi+10,ceil(1.30*Nhi));
    end
    if attempt==maxExpand
        error('Could not bracket exact reliability threshold for %s.',label);
    end
end

% Rebuild once at the final maximum N and binary-search the monotonic path.
alloc = buildAllocationPathLocal(Nhi,q);
while (Nhi-Nlo)>1
    Nmid = floor((Nlo+Nhi)/2);
    Pmid = evalAtNLocal(Nmid,alloc,alpha,cmax);
    if verbose
        fprintf('[%s] binary N=%d, P_OL=%.6f%%\n',label,Nmid,100*Pmid);
    end
    if Pmid<=threshold
        Nlo = Nmid;
    else
        Nhi = Nmid;
    end
end

N95 = Nlo;
Nfail = Nhi;
Nk95 = allocationAtNLocal(alloc,N95);
NkFail = allocationAtNLocal(alloc,Nfail);
[P95,diag95] = exact_binomial_overload_probability(Nk95,alpha,cmax);
Pfail = exact_binomial_overload_probability(NkFail,alpha,cmax);

if ~(Nfail==N95+1 && P95<=threshold && Pfail>threshold)
    error('Final exact crossing sanity check failed for %s.',label);
end

% Small exact neighborhood, useful for source-data tables.
hw = round(opt.NeighborhoodHalfWidth);
Nvec = (max(0,N95-hw):N95+hw).';
if max(Nvec)>size(alloc,1)
    alloc = buildAllocationPathLocal(max(Nvec),q);
end
Pvec = zeros(size(Nvec));
NkMat = zeros(numel(Nvec),5);
for ii=1:numel(Nvec)
    Nk = allocationAtNLocal(alloc,Nvec(ii));
    NkMat(ii,:) = Nk.';
    Pvec(ii) = exact_binomial_overload_probability(Nk,alpha,cmax);
end

out = struct();
out.N95 = N95;
out.N_first_infeasible = Nfail;
out.P_at_N95 = P95;
out.P_at_N95_plus_1 = Pfail;
out.Nk_at_N95 = Nk95;
out.Nk_at_N95_plus_1 = NkFail;
out.Cmix = Cmix;
out.Nharm = Nharm;
out.q = q;
out.pk = pk;
out.alpha = alpha;
out.cmax = cmax;
out.diag_at_N95 = diag95;
out.neighborhood = table(Nvec,NkMat(:,1),NkMat(:,2),NkMat(:,3),NkMat(:,4),NkMat(:,5), ...
    Pvec,100*Pvec,Pvec<=threshold, ...
    'VariableNames',{'N','N_A','N_B','N_C','N_D','N_E', ...
    'P_overload_exact','P_overload_percent','meets_criterion'});
end

function P = evalAtNLocal(N,alloc,alpha,cmax)
Nk = allocationAtNLocal(alloc,N);
P = exact_binomial_overload_probability(Nk,alpha,cmax);
end

function alloc = buildAllocationPathLocal(maxN,q)
maxN = round(maxN);
q = double(q(:)); q=q/sum(q);
K = numel(q);
alloc = zeros(maxN,K);
counts = zeros(K,1);
for n=1:maxN
    target = n*q;
    deficit = target-counts;
    mx = max(deficit);
    cand = find(abs(deficit-mx)<1e-12);
    if numel(cand)>1
        [~,jj] = max(q(cand));
        chosen = cand(jj);
    else
        chosen = cand(1);
    end
    counts(chosen)=counts(chosen)+1;
    alloc(n,:)=counts.';
end
end

function Nk = allocationAtNLocal(alloc,N)
N=round(N);
if N<=0
    Nk=zeros(size(alloc,2),1);
else
    Nk=alloc(N,:).';
end
end
