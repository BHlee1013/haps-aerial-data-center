function alloc = haps_allocation(maxN,q)
% HAPS_ALLOCATION Manuscript sequential-deficit monotonic allocation.
% Row N gives [N_A,...,N_E]. Each increment adds exactly one user equivalent.
% This is NOT an independent largest-remainder allocation at each N.
validateattributes(maxN,{'numeric'},{'scalar','real','finite','integer','nonnegative'});
validateattributes(q,{'numeric'},{'vector','numel',5,'real','finite','nonnegative'});
q=double(q(:));
if sum(q)<=0, error('HAPS:InvalidMixture','The population mixture has zero mass.'); end
q=q/sum(q); alloc=zeros(maxN,5); counts=zeros(5,1);
for n=1:maxN
    deficit=n*q-counts; mx=max(deficit);
    candidates=find(abs(deficit-mx)<1e-12);
    if numel(candidates)>1
        [~,j]=max(q(candidates)); chosen=candidates(j);
    else
        chosen=candidates(1);
    end
    counts(chosen)=counts(chosen)+1; alloc(n,:)=counts.';
end
end
