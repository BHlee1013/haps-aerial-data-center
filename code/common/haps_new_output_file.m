function outputFile = haps_new_output_file(requested)
% HAPS_NEW_OUTPUT_FILE Validate a NEW standalone output path.
% Relative paths resolve against the repository root. Existing files and
% protected reference/source directories are rejected, including symlinks.
p=haps_paths;
if strlength(string(requested))==0
    error('HAPS:OutputRequired','Pass an explicit new output file.');
end
outputFile=char(requested);
isAbsolute=startsWith(outputFile,filesep)||~isempty(regexp(outputFile,'^[A-Za-z]:[\\/]','once'));
if ~isAbsolute,outputFile=fullfile(p.root,outputFile);end
if ~usejava('jvm'),error('HAPS:JVMRequired','Safe path validation requires the MATLAB JVM.');end
jf=javaObject('java.io.File',outputFile);outputFile=char(jf.getCanonicalPath());
protected={p.processed,p.reference,fullfile(p.root,'code'),fullfile(p.root,'models'),p.docs,fullfile(p.root,'supplementary')};
for i=1:numel(protected)
    jf=javaObject('java.io.File',protected{i});base=char(jf.getCanonicalPath());
    if ispc,a=lower(outputFile);b=lower(base);else,a=outputFile;b=base;end
    if strcmp(a,b)||startsWith(a,[b filesep])
        error('HAPS:ProtectedOutput','Cannot write generated outputs in %s.',base);
    end
end
if isfile(outputFile)||isfolder(outputFile)
    error('HAPS:ExistingOutput','Output path already exists: %s',outputFile);
end
parent=fileparts(outputFile);
if ~isfolder(parent)
    [ok,msg]=mkdir(parent);if ~ok,error('HAPS:OutputDirectory','%s',msg);end
end
end
