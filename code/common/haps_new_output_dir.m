function outDir = haps_new_output_dir(requested,kind)
% HAPS_NEW_OUTPUT_DIR Create a NEW folder; never overwrite packaged inputs.
% Existing folders are rejected even when empty. A run can therefore fail
% without changing an earlier result. Explicit relative paths are interpreted
% relative to the repository, not the current working directory.
p=haps_paths;
if nargin<2, kind='run'; end
if nargin<1 || strlength(string(requested))==0
    if strcmp(kind,'figures'), parent=p.figures; else, parent=p.generated; end
    stem=[char(kind) '_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
    outDir=fullfile(parent,stem);
else
    outDir=char(requested);
    isAbsolute=startsWith(outDir,filesep)||~isempty(regexp(outDir,'^[A-Za-z]:[\\/]','once'));
    if ~isAbsolute, outDir=fullfile(p.root,outDir); end
end
% Canonical resolution also blocks ../ paths and symlinks into reference data.
if ~usejava('jvm'), error('HAPS:JVMRequired','Safe path validation requires the MATLAB JVM.'); end
jf=javaObject('java.io.File',outDir); outDir=char(jf.getCanonicalPath());
protected={p.processed,p.reference,fullfile(p.root,'code'),fullfile(p.root,'models'),p.docs,fullfile(p.root,'supplementary')};
for i=1:numel(protected)
    jf=javaObject('java.io.File',protected{i}); base=char(jf.getCanonicalPath());
    if ispc, a=lower(outDir); b=lower(base); else, a=outDir; b=base; end
    if strcmp(a,b)||startsWith(a,[b filesep])
        error('HAPS:ProtectedOutput','Cannot write generated outputs in %s.',base);
    end
end
if isfolder(outDir)||isfile(outDir)
    error('HAPS:ExistingOutput','Output path already exists; choose a new folder: %s',outDir);
end
[ok,msg]=mkdir(outDir);
if ~ok, error('HAPS:OutputDirectory','%s',msg); end
end
