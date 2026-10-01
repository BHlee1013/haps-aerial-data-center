function hex = haps_sha256(filename)
% HAPS_SHA256 Stream a file into SHA-256 without loading it into memory.
filename=haps_require_file(filename);
fid=fopen(filename,'rb');
if fid<0, error('HAPS:FileOpen','Cannot open %s.',filename); end
cleanup=onCleanup(@()fclose(fid));
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes), md.update(typecast(bytes,'int8')); end
end
v=typecast(int8(md.digest()),'uint8');
hex=lower(reshape(dec2hex(v,2).',1,[]));
end
