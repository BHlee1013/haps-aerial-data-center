function f = haps_require_file(f)
% HAPS_REQUIRE_FILE Reject a missing explicit input; never choose a fallback.
if ~(ischar(f)||(isstring(f)&&isscalar(f))) || strlength(string(f))==0
    error('HAPS:MissingFile','An explicit file path is required.');
end
f=char(f);
if ~isfile(f), error('HAPS:MissingFile','Required file not found: %s',f); end
end
