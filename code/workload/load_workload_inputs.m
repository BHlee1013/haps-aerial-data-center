function [pk,alpha] = load_workload_inputs(shareFile,alphaFile)
% LOAD_WORKLOAD_INPUTS Read the reviewed full-precision A-E baseline inputs.
% No raw-trace preprocessing is performed by this function. Row order in the
% CSV is not assumed, and duplicate/missing types are rejected.
p=haps_paths;
if nargin<1, shareFile=fullfile(p.processed,'workload_occupancy.csv'); end
if nargin<2, alphaFile=fullfile(p.processed,'activity_statistics.csv'); end
S=readtable(haps_require_file(shareFile),'TextType','string');
A=readtable(haps_require_file(alphaFile),'TextType','string');
if ~all(ismember({'Type','ElapsedTimeShare_p_k'},S.Properties.VariableNames))|| ...
   ~all(ismember({'Type','alpha_baseline'},A.Properties.VariableNames))
    error('HAPS:WorkloadSchema','Required workload input columns are missing.');
end
pk=zeros(5,1);alpha=zeros(5,1);order=["A","B","C","D","E"];
for k=1:5
    i=find(upper(strtrim(string(S.Type)))==order(k));
    j=find(upper(strtrim(string(A.Type)))==order(k));
    if numel(i)~=1||numel(j)~=1, error('HAPS:WorkloadTypes','Require one row for Type %s.',order(k)); end
    pk(k)=double(S.ElapsedTimeShare_p_k(i));alpha(k)=double(A.alpha_baseline(j));
end
validateattributes(pk,{'numeric'},{'finite','nonnegative'});
validateattributes(alpha,{'numeric'},{'finite','positive','<=',1});
if abs(sum(pk)-1)>1e-10, error('HAPS:WorkloadMixture','Occupancy fractions do not sum to one.'); end
pk=pk/sum(pk);
end
