function [modelFiles, modelHashes] = read_model_manifest(manifestFile)
% READ_MODEL_MANIFEST Read the shipped Simscape model manifest robustly.
% The public manifest is intentionally simple CSV. Parsing the first two
% comma-separated fields from each data line avoids locale-dependent
% delimiter inference and table-variable-name normalization in readtable.

manifestFile = haps_require_file(manifestFile);
lines = readlines(manifestFile,'EmptyLineRule','skip');
lines = strip(lines);
if numel(lines) < 2
    error('HAPS:ModelManifest','Model manifest contains no data rows: %s',manifestFile);
end

% Ignore the header row; only filename and SHA-256 are required by runtime.
lines = lines(2:end);
modelFiles = strings(numel(lines),1);
modelHashes = strings(numel(lines),1);
for i = 1:numel(lines)
    fields = split(lines(i),',');
    if numel(fields) < 2
        error('HAPS:ModelManifest', ...
            'Malformed model-manifest row %d in %s.',i+1,manifestFile);
    end
    modelFiles(i) = strip(fields(1));
    modelHashes(i) = lower(strip(fields(2)));
    if strlength(modelFiles(i)) == 0 || ...
            strlength(modelHashes(i)) ~= 64 || ...
            isempty(regexp(char(modelHashes(i)),'^[0-9a-f]{64}$','once'))
        error('HAPS:ModelManifest', ...
            'Invalid filename or SHA-256 in model-manifest row %d.',i+1);
    end
end

if numel(unique(modelFiles)) ~= numel(modelFiles)
    error('HAPS:ModelManifest','Duplicate model filenames in %s.',manifestFile);
end
end
