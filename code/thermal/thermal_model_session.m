function cleanup = thermal_model_session(cases,outputDir)
% THERMAL_MODEL_SESSION Load exact model files and isolate generated caches.
% Model blocks/solver configuration are not saved or modified on disk. Close
% only models loaded here. Refuse an already-loaded edited/shadowed model.

p = haps_paths;
modelDir = fullfile(p.root,'models','simscape');
if exist('Simulink.SimulationInput','class') ~= 8
    error('HAPS:SimulinkRequired','This command requires Simulink, Simscape and Simscape Fluids.');
end

models = unique(string(cases.model_file),'stable');
loaded = strings(numel(models),1);
nLoaded = 0;

cfg = Simulink.fileGenControl('getConfig');
oldCache = cfg.CacheFolder;
oldCode = cfg.CodeGenFolder;
oldStructure = cfg.CodeGenFolderStructure;
oldPath = path;

Simulink.fileGenControl('set', ...
    'CacheFolder',fullfile(outputDir,'simulink_cache'), ...
    'CodeGenFolder',fullfile(outputDir,'simulink_codegen'), ...
    'createDir',true);

manifestFile = fullfile(modelDir,'model_manifest.csv');
[manifestFiles,manifestHashes] = read_model_manifest(manifestFile);

try
    for modelIdx = 1:numel(models)
        file = haps_require_file(fullfile(modelDir,models(modelIdx)));
        [~,model] = fileparts(file);
        manifestIdx = find(manifestFiles==models(modelIdx));
        if numel(manifestIdx)~=1 || ~strcmpi(haps_sha256(file),manifestHashes(manifestIdx))
            error('HAPS:ModelHash','Model differs from the shipped source snapshot: %s.',file);
        end

        if bdIsLoaded(model)
            jf = java.io.File(get_param(model,'FileName'));
            loadedPath = char(jf.getCanonicalPath());
            jf = java.io.File(file);
            expectedPath = char(jf.getCanonicalPath());
            if ~strcmpi(loadedPath,expectedPath) || strcmp(get_param(model,'Dirty'),'on')
                error('HAPS:LoadedModel','Close or save the edited/conflicting model %s first.',model);
            end
        else
            load_system(file);
            nLoaded = nLoaded + 1;
            loaded(nLoaded) = string(model);
        end
    end
catch ME
    restore_thermal_session(loaded(1:nLoaded),oldCache,oldCode,oldStructure,oldPath);
    rethrow(ME);
end

% Capture an immutable copy after loading succeeds. This avoids the Code
% Analyzer warning caused by onCleanup referencing a mutable parent variable.
loadedFinal = loaded(1:nLoaded);
cleanup = onCleanup(@()restore_thermal_session( ...
    loadedFinal,oldCache,oldCode,oldStructure,oldPath));
end

function restore_thermal_session(loadedModels,oldCache,oldCode,oldStructure,oldPath)
% Restore only state changed by THERMAL_MODEL_SESSION.
for closeIdx = 1:numel(loadedModels)
    modelName = char(loadedModels(closeIdx));
    if bdIsLoaded(modelName)
        close_system(modelName,0);
    end
end
try
    Simulink.fileGenControl('set', ...
        'CacheFolder',oldCache, ...
        'CodeGenFolder',oldCode, ...
        'CodeGenFolderStructure',oldStructure);
catch ME
    warning('HAPS:CacheRestore', ...
        'Restore Simulink cache preferences manually: %s',ME.message);
end
path(oldPath);
end
