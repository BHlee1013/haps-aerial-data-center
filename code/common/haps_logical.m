function x = haps_logical(x)
% HAPS_LOGICAL Read logical CSV columns without treating 'false' as true.
if islogical(x), return; end
if isnumeric(x)
    if any(~isfinite(x(:))|~ismember(x(:),[0,1]))
        error('HAPS:InvalidBoolean','Boolean numeric values must be 0 or 1.');
    end
    x=logical(x); return;
end
s=lower(strtrim(string(x)));
if any(~ismember(s(:),["true","false","1","0"]))
    error('HAPS:InvalidBoolean','Unrecognized boolean text.');
end
x=(s=="true"|s=="1");
end
