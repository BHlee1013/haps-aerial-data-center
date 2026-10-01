function [pairs,info] = load_burstgpt_pairs(filename,varargin)
% LOAD_BURSTGPT_PAIRS Preserve string IDs and stable within-session pairing.
% Cleaning: finite numeric fields, response tokens > 0, elapsed time > 0.
% Requests without a usable Session ID are excluded from session pairing by
% default because session continuity cannot be inferred for them. The number
% of excluded rows is reported in INFO. Use MissingSessionPolicy='error' for
% a strict audit that reproduces the former fail-fast behavior.
% Pair AFTER cleaning. The initiating request defines tokens, elapsed time and
% the day block. Keep next-request gaps >= 0; the caller applies tau later.
% No filename fallback is used. Raw requests are never exported by default.

p = inputParser;
addParameter(p,'MissingSessionPolicy','exclude',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
policy = lower(string(p.Results.MissingSessionPolicy));
if ~ismember(policy,["exclude","error"])
    error('HAPS:MissingSessionPolicy', ...
        'MissingSessionPolicy must be ''exclude'' or ''error''.');
end

filename = haps_require_file(filename);

vSession = 'Session ID';
vTimestamp = 'Timestamp';
vRequest = 'Request tokens';
vResponse = 'Response tokens';
vElapsed = 'Elapsed time';
need = {vSession,vTimestamp,vRequest,vResponse,vElapsed};

opts = detectImportOptions(filename,'VariableNamingRule','preserve');
if ~all(ismember(string(need),string(opts.VariableNames)))
    error('HAPS:BurstGPTSchema','Require columns: %s.',strjoin(string(need),', '));
end
opts.SelectedVariableNames = need;
opts = setvartype(opts,{vSession,vTimestamp},'string');
raw = readtable(filename,opts);
nRaw = height(raw);

sidRaw = strtrim(string(raw{:,vSession}));
badSessionRaw = local_bad_session_id(sidRaw);

requestTokens = local_numeric_column(raw{:,vRequest},vRequest);
responseTokens = local_numeric_column(raw{:,vResponse},vResponse);
elapsedSeconds = local_numeric_column(raw{:,vElapsed},vElapsed);

keepNumeric = isfinite(requestTokens) & isfinite(responseTokens) & ...
    isfinite(elapsedSeconds) & responseTokens > 0 & elapsedSeconds > 0;
nNumericClean = sum(keepNumeric);

orig = (1:nRaw).';
orig = orig(keepNumeric);
raw = raw(keepNumeric,:);
requestTokens = requestTokens(keepNumeric);
responseTokens = responseTokens(keepNumeric);
elapsedSeconds = elapsedSeconds(keepNumeric);
sid = sidRaw(keepNumeric);

badSession = local_bad_session_id(sid);
nMissingAfterNumericCleaning = sum(badSession);
if nMissingAfterNumericCleaning > 0 && policy == "error"
    error('HAPS:MissingSession', ...
        ['Numeric-clean requests contain %d missing, empty, or whitespace-only ' ...
         'session IDs. Use MissingSessionPolicy=''exclude'' to omit requests ' ...
         'whose session continuity cannot be inferred.'], ...
        nMissingAfterNumericCleaning);
end

% Do not invent continuity for unidentified requests. In particular, never
% replace all missing IDs with one shared token and never forward-fill them.
keepSession = ~badSession;
raw = raw(keepSession,:);
requestTokens = requestTokens(keepSession);
responseTokens = responseTokens(keepSession);
elapsedSeconds = elapsedSeconds(keepSession);
orig = orig(keepSession);
sid = sid(keepSession);
nPairingEligible = numel(sid);
if nPairingEligible == 0
    error('HAPS:NoUsableSessions', ...
        'No requests with usable Session IDs remain after cleaning.');
end

textTime = strtrim(string(raw{:,vTimestamp}));
timestamp = str2double(textTime);
if any(isnan(timestamp))
    try
        timestamp = posixtime(datetime(textTime,'TimeZone','UTC'));
    catch ME
        error('HAPS:Timestamp','Timestamp conversion failed: %s',ME.message);
    end
end
if any(~isfinite(timestamp)) || any(requestTokens < 0)
    error('HAPS:InvalidTrace','Require finite timestamps and nonnegative input tokens.');
end

T = table(sid,double(timestamp),double(requestTokens),double(responseTokens), ...
    double(elapsedSeconds),orig,'VariableNames', ...
    {'session_id','timestamp','input_tokens','output_tokens','elapsed_s','original_row'});
T = sortrows(T,{'session_id','timestamp','original_row'});

n = height(T);
nextTimestamp = nan(n,1);
if n > 1
    sameSession = T.session_id(1:end-1)==T.session_id(2:end);
    idx = find(sameSession);
    nextTimestamp(idx) = T.timestamp(idx+1);
end
T.dt_s = nextTimestamp-T.timestamp;
pairs = T(isfinite(T.dt_s) & T.dt_s>=0,:);
pairs.day_block = floor(pairs.timestamp/86400);

info = table(nRaw,nNumericClean,sum(badSessionRaw), ...
    nMissingAfterNumericCleaning,nPairingEligible,height(pairs), ...
    numel(unique(T.session_id)),numel(unique(pairs.day_block)),policy, ...
    string(haps_sha256(filename)), ...
    'VariableNames',{'raw_rows','clean_rows','missing_session_raw_rows', ...
    'missing_session_after_cleaning','pairing_eligible_rows','valid_pairs', ...
    'unique_sessions','day_blocks_before_tau','missing_session_policy','input_sha256'});
end

function bad = local_bad_session_id(sid)
% A usable session ID must be present and non-empty after trimming.
bad = ismissing(sid);
valid = ~bad;
bad(valid) = strlength(sid(valid))==0;
end

function x = local_numeric_column(x,name)
% Convert an imported numeric-like column to a finite double vector when possible.
if ~isnumeric(x)
    x = str2double(strtrim(string(x)));
end
x = double(x(:));
if ~isreal(x)
    error('HAPS:BurstGPTSchema','Column %s must be real-valued.',name);
end
end
