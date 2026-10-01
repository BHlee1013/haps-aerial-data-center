function out = run_mapping_sensitivity(varargin)
% RUN_MAPPING_SENSITIVITY Exact thresholds using full-precision activity inputs.
% Baseline p_k and Cmax stay fixed; only alpha and induced q change.
% Historical Monte-Carlo guesses and comparisons are not production inputs.
paths=haps_paths;
p = inputParser;
addParameter(p,'WorkloadShareFile',fullfile(paths.processed,'workload_occupancy.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'CmaxRegistryFile',fullfile(paths.reference,'exact','general_slo_capacity.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'MappingAlphaFile',fullfile(paths.processed,'mapping_activity.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'ReliabilityThreshold',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);
addParameter(p,'Verbose',true,@(x)islogical(x)||isnumeric(x));
parse(p,varargin{:});
opt = p.Results;

shareFile = char(opt.WorkloadShareFile);
cmaxFile  = char(opt.CmaxRegistryFile);
mapFile   = char(opt.MappingAlphaFile);
outDir    = haps_new_output_dir(opt.OutputDir,'mapping');
threshold = double(opt.ReliabilityThreshold);
verbose   = logical(opt.Verbose);

mustExistLocal(shareFile);
mustExistLocal(cmaxFile);
mustExistLocal(mapFile);


ORDER = ["A","B","C","D","E"];
primaryModels = ["llama31_8b_1xH100_fp8_TP1", ...
                 "llama33_70b_2xH100_fp8_TP2"];

%% 1) Load p_k
Tshare = readtable(shareFile,'VariableNamingRule','preserve');
requireColumnsLocal(Tshare,["Type","ElapsedTimeShare_p_k"],shareFile);
shareType = upper(strtrim(string(Tshare.Type)));
pk = zeros(5,1);
for k = 1:5
    idx = find(shareType==ORDER(k));
    if numel(idx)~=1, error('Missing Type %s in %s.',ORDER(k),shareFile); end
    pk(k) = double(Tshare.ElapsedTimeShare_p_k(idx));
end
validateattributes(pk,{'numeric'},{'finite','nonnegative'});
if abs(sum(pk)-1)>1e-10,error('HAPS:WorkloadMixture','Occupancy fractions must sum to one.');end
pk = pk/sum(pk);

%% 2) Load Cmax registry already produced by the full exact pipeline
Tcmax = readtable(cmaxFile,'VariableNamingRule','preserve');
requireColumnsLocal(Tcmax,["model_key","display_label","Cmax_A","Cmax_B", ...
    "Cmax_C","Cmax_D","Cmax_E","SLO_feasible"],cmaxFile);
Tcmax.model_key = string(Tcmax.model_key);
Tcmax.display_label = string(Tcmax.display_label);

%% 3) Load full-precision mapping alpha values
Tmap = readtable(mapFile,'VariableNamingRule','preserve');
requireColumnsLocal(Tmap,["mapping_key","mapping_label","alpha_A","alpha_B", ...
    "alpha_C","alpha_D","alpha_E"],mapFile);
Tmap.mapping_key = string(Tmap.mapping_key);
Tmap.mapping_label = string(Tmap.mapping_label);
if numel(unique(Tmap.mapping_key))~=height(Tmap)||numel(unique(Tcmax.model_key))~=height(Tcmax)
    error('HAPS:DuplicateKeys','Mapping and capacity keys must be unique.');
end

if sum(Tmap.mapping_key=="baseline")~=1
    error('Mapping file must contain exactly one row with mapping_key="baseline".');
end

if verbose
    fprintf('\n============================================================\n');
    fprintf('EXACT MAPPING SENSITIVITY ONLY\n');
    fprintf('Overload criterion : %.4f%%\n',100*threshold);
    fprintf('Output directory   : %s\n',outDir);
    fprintf('============================================================\n');
    fprintf('p_k = [%.15g %.15g %.15g %.15g %.15g]\n',pk);
end

%% 4) Exact N95 for every mapping x two primary configurations
nRows = height(Tmap)*numel(primaryModels);
rows = cell(nRows,14);
row = 0;

for r = 1:height(Tmap)
    alpha = [double(Tmap.alpha_A(r)); double(Tmap.alpha_B(r)); ...
             double(Tmap.alpha_C(r)); double(Tmap.alpha_D(r)); ...
             double(Tmap.alpha_E(r))];

    if any(~isfinite(alpha) | alpha<=0 | alpha>1)
        error('Invalid alpha values in mapping row %d (%s).',r,Tmap.mapping_key(r));
    end

    for im = 1:numel(primaryModels)
        model = primaryModels(im);
        ci = find(Tcmax.model_key==model,1,'first');
        if isempty(ci), error('Model %s not found in %s.',model,cmaxFile); end
        if ~haps_logical(Tcmax.SLO_feasible(ci))
            error('Primary model %s is marked SLO-infeasible.',model);
        end

        cmax = [double(Tcmax.Cmax_A(ci)); double(Tcmax.Cmax_B(ci)); ...
                double(Tcmax.Cmax_C(ci)); double(Tcmax.Cmax_D(ci)); ...
                double(Tcmax.Cmax_E(ci))];

        initialGuess = NaN;

        label = Tmap.mapping_label(r) + " | " + Tcmax.display_label(ci);
        if verbose
            fprintf('\nMapping: %s\n',label);
            fprintf('alpha = [%.15g %.15g %.15g %.15g %.15g]\n',alpha);
        end

        R = find_exact_reliability_threshold(pk,alpha,cmax, ...
            'ReliabilityThreshold',threshold, ...
            'InitialGuess',initialGuess, ...
            'NeighborhoodHalfWidth',0, ...
            'Verbose',verbose, ...
            'Label',label);

        row = row + 1;
        rows(row,:) = {Tmap.mapping_key(r),Tmap.mapping_label(r), ...
            model,Tcmax.display_label(ci), ...
            alpha(1),alpha(2),alpha(3),alpha(4),alpha(5), ...
            R.N95,R.P_at_N95,R.P_at_N95_plus_1, ...
            NaN,NaN};
    end
end

T = cell2table(rows,'VariableNames',{ ...
    'mapping_key','mapping_label','model_key','display_label', ...
    'alpha_A','alpha_B','alpha_C','alpha_D','alpha_E', ...
    'N95_exact','P_at_N95','P_at_N95_plus_1', ...
    'change_users_vs_baseline','change_percent_vs_baseline'});

% Normalize string columns after cell2table.
T.mapping_key = string(T.mapping_key);
T.mapping_label = string(T.mapping_label);
T.model_key = string(T.model_key);
T.display_label = string(T.display_label);

%% 5) Changes relative to the exact baseline
for im = 1:numel(primaryModels)
    model = primaryModels(im);
    baseIdx = find(T.model_key==model & T.mapping_key=="baseline",1,'first');
    if isempty(baseIdx), error('Exact baseline result missing for %s.',model); end
    baseN = double(T.N95_exact(baseIdx));

    idxs = find(T.model_key==model);
    T.change_users_vs_baseline(idxs) = double(T.N95_exact(idxs)) - baseN;
    T.change_percent_vs_baseline(idxs) = 100*T.change_users_vs_baseline(idxs)/baseN;
end


%% 6) Write ONLY mapping-branch outputs to the requested folder
outFile = fullfile(outDir,'mapping_sensitivity_exact.csv');
writetable(T,outFile);

manifest = table(string(shareFile),string(cmaxFile),string(mapFile),threshold, ...
    "deterministic exact-under-model independent-Binomial reliability", ...
    'VariableNames',{'workload_share_file','cmax_registry_file','mapping_alpha_file', ...
    'overload_threshold','reliability_method'});
writetable(manifest,fullfile(outDir,'run_manifest.csv'));

if verbose
    fprintf('\n============================================================\n');
    fprintf('DONE\n');
    fprintf('Main output: %s\n',outFile);
    fprintf('============================================================\n');
    disp(T(:,{'mapping_label','display_label','N95_exact', ...
        'change_users_vs_baseline','change_percent_vs_baseline'}));
end

out = struct();
out.mapping_sensitivity = T;
out.output_file = outFile;
out.output_dir = outDir;
end

function mustExistLocal(f)
if exist(f,'file')~=2
    error('Required file not found: %s',f);
end
end

function requireColumnsLocal(T,names,fileName)
vars = string(T.Properties.VariableNames);
missing = names(~ismember(names,vars));
if ~isempty(missing)
    error('Missing required column(s) in %s: %s',fileName,strjoin(missing,', '));
end
end
