function out = find_exact_static_balanced_threshold(pk,alpha,cmax,m,varargin)
% FIND_EXACT_STATIC_BALANCED_THRESHOLD
% Finds the largest total population N for which the exact-under-model
% platform overload probability under static balanced partitioning is <=5%
% (or another specified threshold).

validateattributes(pk,{'numeric'},{'real','finite','vector','numel',5,'nonnegative'},mfilename,'pk');
validateattributes(alpha,{'numeric'},{'real','finite','vector','numel',5,'positive','<=',1},mfilename,'alpha');
if sum(pk)<=0, error('HAPS:InvalidMixture','The workload shares must have positive total.'); end
validateattributes(m,{'numeric'},{'real','finite','scalar','integer','positive'},mfilename,'m');

p = inputParser;
addParameter(p,'ReliabilityThreshold',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);
addParameter(p,'InitialGuess',NaN,@(x)isnumeric(x)&&isscalar(x));
addParameter(p,'NeighborhoodHalfWidth',2,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'Verbose',false,@(x)islogical(x)||isnumeric(x));
addParameter(p,'Label','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
opt=p.Results;

pk=double(pk(:)); alpha=double(alpha(:)); cmax=double(cmax(:));
pk=pk/sum(pk);
q=(pk./alpha); q=q/sum(q);
threshold=double(opt.ReliabilityThreshold);
label=string(opt.Label);
verbose=logical(opt.Verbose);
m=round(m);

if m<1, error('m must be >=1.'); end
if any(cmax<=0|~isfinite(cmax)), error('cmax must be positive and finite.'); end

Cmix=1/sum(pk./cmax);
NharmSingle=Cmix*sum(pk./alpha);

if isfinite(opt.InitialGuess) && opt.InitialGuess>0
    Nlo=max(0,floor(0.75*opt.InitialGuess));
    Nhi=max(Nlo+1,ceil(1.25*opt.InitialGuess));
else
    Nlo=max(0,floor(0.20*m*NharmSingle));
    Nhi=max(Nlo+1,ceil(m*NharmSingle));
end

maxExpand=12;
for attempt=1:maxExpand
    alloc=buildAllocationPathLocal(Nhi,q);
    Plo=evalStaticAtNLocal(Nlo,alloc,alpha,cmax,m);
    Phi=evalStaticAtNLocal(Nhi,alloc,alpha,cmax,m);
    if verbose
        fprintf('[%s static] bracket %d: N=%d -> %.6f%%, N=%d -> %.6f%%\n', ...
            label,attempt,Nlo,100*Plo,Nhi,100*Phi);
    end
    if Plo<=threshold && Phi>threshold, break; end
    if Plo>threshold
        NloNew=max(0,floor(0.70*Nlo));
        if NloNew==Nlo && Nlo>0, NloNew=Nlo-1; end
        Nlo=NloNew;
    end
    if Phi<=threshold
        Nhi=max(Nhi+10,ceil(1.30*Nhi));
    end
    if attempt==maxExpand
        error('Could not bracket static exact threshold for %s.',label);
    end
end

alloc=buildAllocationPathLocal(Nhi,q);
while (Nhi-Nlo)>1
    Nmid=floor((Nlo+Nhi)/2);
    Pmid=evalStaticAtNLocal(Nmid,alloc,alpha,cmax,m);
    if verbose
        fprintf('[%s static] binary N=%d, P_OL=%.6f%%\n',label,Nmid,100*Pmid);
    end
    if Pmid<=threshold, Nlo=Nmid; else, Nhi=Nmid; end
end

N95=Nlo; Nfail=Nhi;
Nk95=allocationAtNLocal(alloc,N95);
NkFail=allocationAtNLocal(alloc,Nfail);
[P95,pInst95,part95]=exact_static_balanced_overload_probability(Nk95,alpha,cmax,m);
Pfail=exact_static_balanced_overload_probability(NkFail,alpha,cmax,m);

if ~(Nfail==N95+1 && P95<=threshold && Pfail>threshold)
    error('Final static exact crossing sanity check failed for %s.',label);
end

hw=round(opt.NeighborhoodHalfWidth);
Nvec=(max(0,N95-hw):N95+hw).';
if max(Nvec)>size(alloc,1), alloc=buildAllocationPathLocal(max(Nvec),q); end
Pvec=zeros(size(Nvec));
for ii=1:numel(Nvec)
    Nk=allocationAtNLocal(alloc,Nvec(ii));
    Pvec(ii)=exact_static_balanced_overload_probability(Nk,alpha,cmax,m);
end

out=struct();
out.N95=N95;
out.N_first_infeasible=Nfail;
out.P_at_N95=P95;
out.P_at_N95_plus_1=Pfail;
out.Nk_at_N95=Nk95;
out.partition_at_N95=part95;
out.instance_P_at_N95=pInst95;
out.Nharm_single=NharmSingle;
out.linear_Nharm=m*NharmSingle;
out.q=q;
out.neighborhood=table(Nvec,Pvec,100*Pvec,Pvec<=threshold, ...
    'VariableNames',{'N','P_overload_exact','P_overload_percent','meets_criterion'});
end

function P=evalStaticAtNLocal(N,alloc,alpha,cmax,m)
Nk=allocationAtNLocal(alloc,N);
P=exact_static_balanced_overload_probability(Nk,alpha,cmax,m);
end

function alloc=buildAllocationPathLocal(maxN,q)
maxN=round(maxN); q=double(q(:)); q=q/sum(q); K=numel(q);
alloc=zeros(maxN,K); counts=zeros(K,1);
for n=1:maxN
    target=n*q; deficit=target-counts; mx=max(deficit);
    cand=find(abs(deficit-mx)<1e-12);
    if numel(cand)>1
        [~,jj]=max(q(cand)); chosen=cand(jj);
    else
        chosen=cand(1);
    end
    counts(chosen)=counts(chosen)+1;
    alloc(n,:)=counts.';
end
end

function Nk=allocationAtNLocal(alloc,N)
N=round(N);
if N<=0, Nk=zeros(size(alloc,2),1); else, Nk=alloc(N,:).'; end
end
