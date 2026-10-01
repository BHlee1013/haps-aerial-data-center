function paths = setup_haps()
% SETUP_HAPS Add only public code directories to the MATLAB search path.
% Run once after extracting this repository. No raw data or model paths are
% added recursively, so a historical script cannot shadow a current function.
root=fileparts(mfilename('fullpath'));
folders={'common','workload','serving_capacity','communication','thermal', ...
    'haps_feasibility','figures','validation'};
for i=1:numel(folders), addpath(fullfile(root,'code',folders{i})); end
paths=haps_paths;
fprintf('HAPS repository: %s\n',root);
fprintf('Stage 2.2: workload, serving, exact reliability, communication, payload, thermal and MC.\n');
end
