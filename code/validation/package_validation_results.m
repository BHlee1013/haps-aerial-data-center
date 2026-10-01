function zipFile = package_validation_results(runFolders,varargin)
% PACKAGE_VALIDATION_RESULTS Zip selected generated runs for manual review.
% Includes CSV/TXT/JSON/MD/PNG/PDF only; excludes model caches, MAT/FIG files,
% generated code and raw trace inputs. Review files before sharing publicly.
% runFolders must be beneath data/results/generated in THIS repository.
p=inputParser;addParameter(p,'IncludePDF',true,@(x)islogical(x)&&isscalar(x));parse(p,varargin{:});
p0=haps_paths;folders=string(runFolders);folders=folders(:);files=strings(0,1);
j=java.io.File(p0.generated);base=char(j.getCanonicalPath());
for k=1:numel(folders)
    j=java.io.File(char(folders(k)));folder=char(j.getCanonicalPath());
    a=folder;b=base;if ispc,a=lower(a);b=lower(b);end
    if ~startsWith(a,[b filesep])||~isfolder(folder)
        error('HAPS:BundlePath','Select an existing run folder beneath %s.',base);
    end
    F=dir(fullfile(folder,'**','*'));
    for i=1:numel(F)
        if F(i).isdir,continue;end
        file=fullfile(F(i).folder,F(i).name);relative=string(file(numel(base)+2:end));
        normalized=replace(relative,'\','/');[~,~,ext]=fileparts(file);
        allowed=ismember(lower(string(ext)),[".csv",".txt",".json",".md",".png"]);
        allowed=allowed||(p.Results.IncludePDF&&strcmpi(ext,'.pdf'));
        if allowed&&~contains(normalized,'simulink_cache/')&&~contains(normalized,'simulink_codegen/')
            files(end+1,1)=relative; %#ok<AGROW>
        end
    end
end
files=unique(files,'stable');if isempty(files),error('HAPS:EmptyBundle','No reviewable output files found.');end
zipFile=haps_new_output_file(fullfile(base,['stage2_validation_bundle_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.zip']));
zip(zipFile,cellstr(files),base);fprintf('Review bundle: %s (%d files)\n',zipFile,numel(files));
end
