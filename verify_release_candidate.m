function report = verify_release_candidate()
% VERIFY_RELEASE_CANDIDATE Check package integrity without running analysis.
% Run setup_haps first. This verifier checks packaged file SHA-256 values,
% the unchanged inherited computational subset and accidental mixed code files.
% It does not execute Simscape, exact searches, Monte Carlo or raw processing.
% A passing hash check is NOT an assertion of publication rights or model validity.

root = fileparts(mfilename('fullpath'));
expectedHelper = fullfile(root,'code','common','haps_sha256.m');
actualHelper = which('haps_sha256');
if isempty(actualHelper) || ~strcmpi(strrep(actualHelper,'\','/'), ...
        strrep(expectedHelper,'\','/'))
    error('HAPS:IntegrityPath', ...
        'Run setup_haps from this extracted repository first; a different hash helper is active.');
end

manifestPath = fullfile(root,'docs','release_file_checksums.csv');
anchorPath = fullfile(root,'SHA256SUMS');
if ~isfile(manifestPath) || ~isfile(anchorPath)
    error('HAPS:IntegrityManifest','The checksum manifest or its SHA256SUMS anchor is missing.');
end
anchor = strtrim(fileread(anchorPath));
token = regexp(anchor, ...
    '^([0-9a-fA-F]{64})  docs/release_file_checksums\.csv$', ...
    'tokens','once');
if isempty(token) || ~strcmpi(haps_sha256(manifestPath),token{1})
    error('HAPS:IntegrityAnchor', ...
        'The package checksum list was modified. Start from the original RC ZIP or rebuild the release manifest.');
end

manifest = readChecksumList(manifestPath);
packageChecks = verifyList(root,manifest);
frozen = readChecksumList(fullfile(root,'docs','frozen_computational_files.csv'));
frozenChecks = verifyList(root,frozen);
unlisted = findUnlistedCode(root,manifest.file);
meta = jsondecode(fileread(fullfile(root,'docs','release_status.json')));

packageOK = all(packageChecks.passed);
frozenOK = all(frozenChecks.passed);
cleanCode = isempty(unlisted);
report = struct();
report.version = string(meta.version);
report.package_checks = packageChecks;
report.frozen_checks = frozenChecks;
report.unlisted_computational_files = unlisted;
report.passed = packageOK && frozenOK && cleanCode;
report.publication_ready = logical(meta.publication_ready);
report.publication_gates = meta.publication_gates;
report.summary = table(report.version,height(packageChecks),height(frozenChecks), ...
    packageOK,frozenOK,cleanCode,report.publication_ready, ...
    'VariableNames',{'version','package_files_checked','frozen_files_checked', ...
    'package_integrity_passed','computational_freeze_passed', ...
    'no_unlisted_code','publication_ready'});

if report.passed
    fprintf('PASS: %d packaged files match the release checksums.\n',height(packageChecks));
    fprintf('PASS: %d inherited computational files remain byte-identical to the validated baseline.\n',height(frozenChecks));
    fprintf('No simulation or scientific calculation was run.\n');
else
    fprintf('FAIL: package integrity or the computational freeze differs.\n');
    disp(packageChecks(~packageChecks.passed,:));
    disp(frozenChecks(~frozenChecks.passed,:));
    disp(unlisted);
end
if ~report.publication_ready
    fprintf(['Publication approval is separate and remains pending; ' ...
        'see docs/publication_checklist.md.\n']);
end
end

function T = readChecksumList(filename)
% The release writer emits exactly three unquoted ASCII fields per line.
% Explicit parsing avoids locale-dependent CSV delimiter/header inference.
if ~isfile(filename)
    error('HAPS:IntegrityManifest','Missing checksum list: %s',filename);
end
text = fileread(filename);
if ~isempty(text) && double(text(1))==65279
    text = text(2:end);
end
lines = regexp(text,'\r\n|\n|\r','split');
lines = lines(~cellfun('isempty',lines));
if isempty(lines) || ~strcmp(strtrim(lines{1}),'file,bytes,sha256')
    error('HAPS:IntegritySchema','Unexpected checksum schema: %s',filename);
end
n = numel(lines)-1;
file = strings(n,1);
bytes = zeros(n,1);
sha256 = strings(n,1);
for k = 1:n
    parts = regexp(strtrim(lines{k+1}), ...
        '^([^,]+),([0-9]+),([0-9a-fA-F]{64})$','tokens','once');
    if isempty(parts)
        error('HAPS:IntegritySchema','Malformed checksum row %d in %s.',k+1,filename);
    end
    rel = parts{1};
    if startsWith(rel,'/') || contains(rel,'\') || contains(rel,':') || ...
            ~isempty(regexp(rel,'(^|/)\.\.(/|$)','once'))
        error('HAPS:IntegrityPath','Checksum paths must be safe repository-relative paths.');
    end
    file(k) = string(rel);
    bytes(k) = str2double(parts{2});
    sha256(k) = lower(string(parts{3}));
end
if numel(unique(file))~=n || n==0
    error('HAPS:IntegritySchema','Duplicate or empty checksum list: %s',filename);
end
T = table(file,bytes,sha256);
end

function T = verifyList(root,list)
file = list.file;
n = height(list);
exists = false(n,1);
size_ok = false(n,1);
hash_ok = false(n,1);
for k = 1:n
    path = fullfile(root,strrep(char(file(k)),'/',filesep));
    exists(k) = isfile(path);
    if exists(k)
        item = dir(path);
        size_ok(k) = item.bytes==list.bytes(k);
        hash_ok(k) = strcmpi(haps_sha256(path),list.sha256(k));
    end
end
passed = exists & size_ok & hash_ok;
T = table(file,exists,size_ok,hash_ok,passed);
end

function extra = findUnlistedCode(root,knownFiles)
% Ignore generated outputs; catch accidentally mixed source/model/input files.
items = [dir(fullfile(root,'*.m')); ...
    dir(fullfile(root,'code','**','*.m')); ...
    dir(fullfile(root,'code','**','*.py')); ...
    dir(fullfile(root,'models','**','*.slx')); ...
    dir(fullfile(root,'data','processed','**','*.csv'))];
extra = strings(numel(items),1);
count = 0;
for k = 1:numel(items)
    absolute = fullfile(items(k).folder,items(k).name);
    relative = strrep(absolute(numel(root)+2:end),'\','/');
    if ~ismember(string(relative),knownFiles)
        count = count+1;
        extra(count) = string(relative);
    end
end
extra = extra(1:count);
end
