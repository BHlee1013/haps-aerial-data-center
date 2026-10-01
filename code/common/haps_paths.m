function p = haps_paths()
% HAPS_PATHS Resolve paths from this file, never from a user's working folder.
p.root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
p.processed=fullfile(p.root,'data','processed');
p.reference=fullfile(p.root,'data','results','reference');
p.generated=fullfile(p.root,'data','results','generated');
p.figures=fullfile(p.root,'figures','generated');
p.docs=fullfile(p.root,'docs');
end
