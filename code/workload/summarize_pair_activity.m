function T = summarize_pair_activity(pairs,membership)
% SUMMARIZE_PAIR_ACTIVITY alpha = sum(R) / (sum(R)+sum(max(dt-R,0))).
% Independent membership columns deliberately retain overlap between types.
R=double(pairs.elapsed_s);Z=max(double(pairs.dt_s)-R,0);
n=sum(membership,1).';sumR=zeros(5,1);sumZ=zeros(5,1);
for k=1:5,sumR(k)=sum(R(membership(:,k)));sumZ(k)=sum(Z(membership(:,k)));end
meanR=sumR./n;meanZ=sumZ./n;alpha=sumR./(sumR+sumZ);
T=table(["A";"B";"C";"D";"E"],n,meanR,meanZ,alpha, ...
    'VariableNames',{'Type','n_pairs','mean_R_s','mean_Z_s','alpha'});
end
