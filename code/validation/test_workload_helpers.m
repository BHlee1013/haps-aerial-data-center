function report = test_workload_helpers()
% TEST_WORKLOAD_HELPERS Synthetic checks; does not use or replace BurstGPT.
% Tests stable pairing, string-ID preservation, numeric cleaning, and the
% explicit policy for missing/empty/whitespace-only Session IDs.

names = strings(0,1);
passed = false(0,1);

% -------------------------------------------------------------------------
% Baseline pairing semantics.
% -------------------------------------------------------------------------
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s'));
file = fullfile(folder,'synthetic.csv');
sid = [repmat("9007199254740992",3,1);repmat("9007199254740993",4,1)];
t = [0;5;10;2;7;12;7];
req = [200;200;200;1000;1000;1000;1000];
res = [200;0;200;1000;1000;1000;1000];
elapsed = [2;2;3;2;2;2;1];
T = table(sid,t,req,res,elapsed,'VariableNames', ...
    {'Session ID','Timestamp','Request tokens','Response tokens','Elapsed time'});
writetable(T,file);
[Q,info] = load_burstgpt_pairs(file);
[labels,M] = classify_workload_pairs(Q);
A = summarize_pair_activity(Q,M);

add("synthetic_row_counts", ...
    info.raw_rows==7 && info.clean_rows==6 && info.pairing_eligible_rows==6 && height(Q)==4);
add("large_string_ids_preserved", ...
    numel(unique(Q.session_id))==2 && all(ismember(unique(Q.session_id),unique(sid))));
add("clean_before_pairing",Q.dt_s(Q.session_id==sid(1))==10);
add("stable_tie_pair",sum(Q.dt_s==0)==1 && Q.original_row(Q.dt_s==0)==5);
add("range_A_activity",abs(A.alpha(1)-.2)<1e-14);
add("overlap_windows_not_partitioned", ...
    A.n_pairs(2)==3 && A.n_pairs(3)==3 && abs(A.alpha(2)-5/12)<1e-14);
add("distance_labels",labels(1)==1 && all(labels(2:end)==2));

% -------------------------------------------------------------------------
% Missing-session behavior.
% Valid sessions must pair exactly as if unusable-ID rows were absent.
% -------------------------------------------------------------------------
fileMissing = fullfile(folder,'synthetic_missing_sessions.csv');
sid2 = ["A";missing;"";"   ";"A";"B";"B";missing];
t2 = [0;1;2;3;10;20;25;30];
req2 = repmat(200,8,1);
res2 = [200;200;200;200;200;200;200;0]; % last row removed numerically first
elapsed2 = repmat(1,8,1);
T2 = table(sid2,t2,req2,res2,elapsed2,'VariableNames', ...
    {'Session ID','Timestamp','Request tokens','Response tokens','Elapsed time'});
writetable(T2,fileMissing);
[Q2,info2] = load_burstgpt_pairs(fileMissing);
add("missing_session_rows_excluded", ...
    info2.clean_rows==7 && info2.missing_session_after_cleaning==3 && ...
    info2.pairing_eligible_rows==4 && height(Q2)==2);
add("missing_session_valid_pairs_preserved", ...
    all(sort(Q2.dt_s)==[5;10]) && all(ismember(unique(Q2.session_id),["A";"B"])));
add("missing_session_after_numeric_cleaning_count", ...
    info2.missing_session_raw_rows==4 && info2.missing_session_after_cleaning==3);

strictRaised = false;
try
    load_burstgpt_pairs(fileMissing,'MissingSessionPolicy','error');
catch ME
    strictRaised = strcmp(ME.identifier,'HAPS:MissingSession');
end
add("missing_session_strict_mode",strictRaised);

% All IDs unusable: exclusion mode must stop explicitly, not fabricate pairs.
fileAllMissing = fullfile(folder,'synthetic_all_missing.csv');
T3 = table([missing;""],[0;1],[200;200],[200;200],[1;1], ...
    'VariableNames',{'Session ID','Timestamp','Request tokens','Response tokens','Elapsed time'});
writetable(T3,fileAllMissing);
allMissingRaised = false;
try
    load_burstgpt_pairs(fileAllMissing);
catch ME
    allMissingRaised = strcmp(ME.identifier,'HAPS:NoUsableSessions');
end
add("all_missing_sessions_fail_explicitly",allMissingRaised);

report = table(names,passed,'VariableNames',{'check','passed'});
if ~all(passed)
    disp(report(~report.passed,:));
    error('HAPS:WorkloadUnitTest','A synthetic workload check failed.');
end

    function add(name,value)
        names(end+1,1) = string(name);
        passed(end+1,1) = isscalar(value) && logical(value);
    end
end
