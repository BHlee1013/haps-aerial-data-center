#!/usr/bin/env python3
"""Read-only Stage-1 release regression checks (not MATLAB execution).

Usage: python code/validation/verify_release.py [--report PATH] [--skip-engine]
Only the optional report path is written. Reference CSVs are never changed.
Requires numpy, pandas and scipy. The packaged MATLAB commands do not require
Python. Checks use full-precision source data, not rounded manuscript values.
"""
from __future__ import annotations
import argparse, hashlib, json, re, sys, itertools
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.stats import binom
from reference_math import (PRIMARY,TYPES,workload,allocation,total_active_pmf,
                            exact_probability,derive_communication,derive_payload,logical)
ROOT=Path(__file__).resolve().parents[2]
CHECKS=[]
def check(name,ok,detail=''):
    ok=bool(ok);CHECKS.append(dict(check=name,passed=ok,detail=detail))
    if not ok:raise AssertionError(name+': '+detail)
def close(name,a,b,atol=1e-10,rtol=1e-11):
    a=np.asarray(a,float);b=np.asarray(b,float)
    with np.errstate(invalid="ignore"):
        delta=np.abs(a-b)
    finite=delta[np.isfinite(delta)]
    err=float(finite.max()) if finite.size else 0.
    check(name,a.shape==b.shape and np.allclose(a,b,atol=atol,rtol=rtol,equal_nan=True),f'max_abs_error={err:.4g}')
def table_close(name,a,b):
    check(name+'_schema',list(a.columns)==list(b.columns) and len(a)==len(b))
    for c in a:
        if pd.api.types.is_numeric_dtype(a[c]) and pd.api.types.is_numeric_dtype(b[c]):close(name+'_'+c,a[c],b[c],atol=2e-8)
        elif pd.api.types.is_bool_dtype(a[c]):check(name+'_'+c,np.array_equal(logical(a[c]),logical(b[c])))
        else:check(name+'_'+c,np.array_equal(a[c].fillna('').astype(str),b[c].fillna('').astype(str)))
def main(skip_engine=False):
    p=ROOT/'data/processed';r=ROOT/'data/results/reference';e=r/'exact'
    pk,alpha,q=workload(ROOT);single=pd.read_csv(e/'single_instance_exact.csv')
    check('normalized_workload',abs(pk.sum()-1)<1e-14 and np.all(alpha>0) and np.all(alpha<=1))
    s=single.set_index('model_key');vals=[5876,7245,1337,991,936,2784]
    close('current_single_N95',single.N95_exact.iloc[:6],vals,atol=0,rtol=0)
    check('a100_full_mix_infeasible',not bool(single.SLO_feasible.iloc[-1]) and np.isnan(single.N95_exact.iloc[-1]))
    close('serving_efficiency',single.serving_efficiency_user_eq_per_kW,single.N95_exact/single.IT_power_kW)
    check('single_adjacent_crossings',np.all(single.P_at_N95.iloc[:6]<=.05)&np.all(single.P_at_N95_plus_1.iloc[:6]>.05))
    alloc=allocation(int(single.N95_exact.max())+1,q)
    check('allocation_monotonic',np.all(np.diff(np.r_[np.zeros((1,5),int),alloc],axis=0)>=0))
    check('allocation_totals',np.array_equal(alloc.sum(axis=1),np.arange(1,len(alloc)+1)))
    for i,row in single.iloc[:6].iterrows():
        nk=row[['N_'+k for k in TYPES]].to_numpy(float)
        close('stored_Nk_'+str(i),nk,alloc[int(row.N95_exact)-1],atol=0,rtol=0)
        cm=row[['Cmax_'+k for k in TYPES]].to_numpy(float)
        cmix=1/np.sum(pk/cm);nh=cmix*np.sum(pk/alpha)
        close('harmonic_'+str(i),[cmix,nh],[row.Cmix,row.Nharm])
    # Reconstruct general Cmax from the benchmark, independently of saved Cmax.
    nim=pd.read_csv(p/'nim_benchmark.csv');cap=pd.read_csv(e/'general_slo_capacity.csv').set_index('model_key')
    for key in cap.index:
        for kind in TYPES:
            t=nim[(nim.model_key==key)&(nim.type_key==kind)].sort_values('concurrency')
            check('benchmark_unique_'+key+'_'+kind,len(t)>0 and np.all(np.diff(t.concurrency)>0))
            caps=[]
            for col,lim in [('ttft_ms',2000),('itl_ms',100)]:
                x=t.concurrency.to_numpy(float);y=np.maximum.accumulate(t[col].to_numpy(float))
                if y[0]>lim:v=0
                elif np.all(y<=lim):v=x[-1]
                else:
                    j=np.flatnonzero(y>lim)[0];v=x[j-1]+(lim-y[j-1])/(y[j]-y[j-1])*(x[j]-x[j-1])
                caps.append(v)
            close('cmax_'+key+'_'+kind,min(caps),cap.loc[key,'Cmax_'+kind],atol=1e-10)
    # Full communication and payload table regeneration from current inputs.
    com=derive_communication(ROOT)
    for name,t in com.items():table_close('communication_'+name,t,pd.read_csv(r/'communication'/name))
    payload=derive_payload(ROOT,com['radio_power.csv'])
    for name,t in payload.items():table_close('payload_'+name,t,pd.read_csv(r/'payload'/name))
    qtab=pd.read_csv(e/'activity_quantiles_exact.csv').set_index('model_key')
    for key in PRIMARY:
        rr=com['downlink_rates.csv'];rr=rr[(rr.model_key==key)&(rr.bytes_per_token==6)].iloc[0];qr=qtab.loc[key]
        close('exact_activity_'+key,[rr.mean_active_users,rr.p50_active_users,rr.p95_active_users,rr.p99_active_users],
              [qr.mean_active,qr.P50_active,qr.P95_active,qr.P99_active],atol=1e-9)
        pmf=com['active_user_pmf.csv'];pmf=pmf[pmf.model_key==key]
        close('pmf_sum_'+key,pmf.probability.sum(),1.,atol=2e-14)
        check('pmf_nonnegative_'+key,np.all(pmf.probability>=0) and np.all(np.diff(pmf.cdf)>=-1e-14))
    # Fig. 5d compare to the actual final author export, not an older plotter.
    be=com['auxiliary_parity.csv'];be=be[(be.bytes_per_token==6)&(be.slant_distance_km==20)&(be.link_scenario=='snr_floor_0dB')&(be.ground_cooling_ratio==.05)&(be.earth_bs_type!='RRH')].copy()
    be.loc[be.earth_bs_type=='Macro','earth_bs_type']='Macro/RRH'
    ref=pd.read_csv(r/'fig05d_author_export.csv')
    merged=be.merge(ref,on=['earth_bs_type','analysis_NTRX'],suffixes=('_new','_author'),validate='one_to_one')
    check('fig05d_rows',len(merged)==16)
    for col in ['communication_power_W','HAPS_auxiliary_power_W','fan_power_W','IT_power_W','break_even_ground_cooling_percent']:
        close('fig05d_'+col,merged[col+'_new'],merged[col+'_author'])
    dep=payload['deployment_limits.csv'];l=dep[(dep.platform=='Stratobus')&(dep.model_key=='llama31_8b_1xL40S_fp8_TP1')].iloc[0]
    check('l40s_binding_cap',l.binding_constraint=='server_gpu_cap' and l.deployable_instances==10 and l.uncapped_mass_bound==129 and l.uncapped_aux_power_bound==12)
    assign=pd.read_csv(e/'platform_assignment_exact.csv');ref6=pd.read_csv(r/'fig06d_author_export.csv')
    cols=list(ref6.columns);keys=['platform','model_key']
    joined=assign.merge(ref6,on=keys,suffixes=('_new','_author'),validate='one_to_one')
    for col in cols:
        if col in keys or col=='display_label':continue
        close('fig06d_'+col,joined[col+'_new'],joined[col+'_author'])
    fleet=pd.read_csv(e/'fleet_sizing_exact.csv');fleet_ref=pd.read_csv(r/'fig06e_author_export.csv')
    fleet=fleet.sort_values(['platform','target_user_equivalents']).reset_index(drop=True);fleet_ref=fleet_ref.sort_values(['platform','target_user_equivalents']).reset_index(drop=True)
    table_close('fig06e',fleet,fleet_ref)
    close('fleet_ceiling',fleet.minimum_active_HAPS_count,np.ceil(fleet.target_user_equivalents/fleet.best_exact_NHAPS95),atol=0,rtol=0)
    for _,row in assign.iterrows():
        tag=row.platform+'_'+row.model_key
        close('linear_reference_'+tag,row.linear_mN95_exact,row.m_instances*row.single_N95_exact,atol=0,rtol=0)
        check('platform_crossing_'+tag,row.P_pooled_at_NHAPS95<=.05<row.P_pooled_at_NHAPS95_plus_1 and row.P_static_at_NHAPS95<=.05<row.P_static_at_NHAPS95_plus_1)
    # Full-precision mapping stays separate from any historical MC metadata.
    mi=pd.read_csv(p/'mapping_activity.csv').set_index('mapping_key');mo=pd.read_csv(r/'mapping/mapping_sensitivity_exact.csv')
    for _,row in mo.iterrows():
        close('mapping_inputs_'+row.mapping_key+'_'+row.model_key,row[['alpha_'+k for k in TYPES]],mi.loc[row.mapping_key,['alpha_'+k for k in TYPES]],atol=1e-15)
        check('mapping_crossing_'+row.mapping_key+'_'+row.model_key,row.P_at_N95<=.05<row.P_at_N95_plus_1)
    # MC validation: recompute counts, intervals and fully bracketed diagnostics.
    seeds=pd.read_csv(r/'validation/independent_seed_diagnostic_per_seed.csv')
    check('independent_seed_brackets',len(seeds)==40 and not logical(seeds.left_censored).any() and not logical(seeds.right_censored).any())
    expected_stats=[[5873.75,5873.5,5.11833648962753,5866,5888],[993.95,1001.5,39.4467996166989,936,1048]]
    for i,family in enumerate(['8b','70b']):
        curve=pd.read_csv(r/f'validation/{family}_pooled_mc_curve.csv');summ=pd.read_csv(r/f'validation/{family}_pooled_mc_summary.csv').iloc[0]
        prob=curve.pooled_overload_count/curve.pooled_total_snapshots;se=np.sqrt(prob*(1-prob)/curve.pooled_total_snapshots)
        close(family+'_mc_count_probability',curve.P_overload_pooled,prob)
        close(family+'_mc_se',curve.MC_standard_error,se)
        close(family+'_mc_ci_low',curve.CI95_low_normal,np.maximum(0,prob-1.96*se))
        close(family+'_mc_ci_high',curve.CI95_high_normal,np.minimum(1,prob+1.96*se))
        check(family+'_mc_total_snapshots',np.all(curve.pooled_total_snapshots==2000000))
        threshold=int(curve.loc[curve.P_overload_pooled<=.05,'N'].max())
        check(family+'_mc_threshold',threshold==summ.N95_pooled_MC)
        x=seeds.loc[seeds.model_key==PRIMARY[i],'N95'];check(family+'_seed_count',len(x)==20)
        close(family+'_independent_statistics',[x.mean(),x.median(),x.std(ddof=1),x.min(),x.max()],expected_stats[i])
        rr=curve[curve.N==summ.exact_reference_N95].iloc[0];pe=float(s.loc[PRIMARY[i]].P_at_N95)
        check(family+'_probability_compatibility',rr.CI95_low_normal<=pe<=rr.CI95_high_normal)
    if not skip_engine:
        # Tiny fully enumerated case checks equality semantics independently.
        nsmall=np.array([2,1,1,1,1]);asmall=np.array([.2,.1,.3,.15,.25]);csmall=np.array([2,2,3,4,2.])
        brute=0.
        for x in itertools.product(*[range(n+1) for n in nsmall]):
            if np.sum(np.array(x)/csmall)>1+128*np.finfo(float).eps:
                brute+=np.prod(binom.pmf(x,nsmall,asmall))
        close('exact_engine_bruteforce',exact_probability(nsmall,asmall,csmall),brute,atol=1e-13)
        for key in PRIMARY:
            row=s.loc[key];n=int(row.N95_exact);cm=row[['Cmax_'+k for k in TYPES]].to_numpy(float)
            for off,col in [(0,'P_at_N95'),(1,'P_at_N95_plus_1')]:
                close('independent_exact_boundary_'+key+'_'+str(off),exact_probability(alloc[n+off-1],alpha,cm),row[col],atol=1e-10)
    # Check the constant used by the native MATLAB validation against its source.
    native=(ROOT/'code/validation/validate_release.m').read_text(encoding='utf-8')
    match=re.search(r'payload_bearing_radiated_Tx_W\(floorMask\)-([0-9.]+)',native)
    check('native_floor_anchor_present',match is not None)
    floor=com['link_budget.csv'];floor=floor[(floor.link_scenario=='snr_floor_0dB')&(floor.rate_stat=='p95')&(floor.slant_distance_km==60)]
    close('native_floor_anchor_matches_reference',floor.payload_bearing_radiated_Tx_W,np.full(len(floor),float(match.group(1))),atol=1e-12)
    # Static package checks (not MATLAB compilation).
    for f in sorted(ROOT.rglob('*.m')):
        text=f.read_text(encoding='utf-8');match=re.search(r'^function\s+(?:\[[^\]]+\]|\w+)\s*=\s*(\w+)\s*\(',text,re.M)
        if not match:match=re.search(r'^function\s+(\w+)\s*\(',text,re.M)
        check('matlab_filename_'+f.stem,match is not None and match.group(1)==f.stem)
        check('english_code_'+f.stem,not re.search('[\uac00-\ud7a3]',text))
        check('no_local_paths_'+f.stem,'/mnt/data' not in text and not re.search(r'[A-Za-z]:\\Users\\',text))
    check('no_obsolete_production_runners',not any(ROOT.rglob('run_fig6a_all_configurations_v1.m')) and not any(ROOT.rglob('run_fig6de_platform_reliability_v2_4.m')))
    return CHECKS

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--report',type=Path);ap.add_argument('--skip-engine',action='store_true');args=ap.parse_args()
    error=None
    try:main(args.skip_engine)
    except Exception as exc:error=repr(exc)
    report={'scope':'Independent Python arithmetic and static-file checks. MATLAB and Simscape were NOT executed.', 'passed':error is None,'checks_passed':sum(c['passed'] for c in CHECKS),'checks_total':len(CHECKS),'error':error,'checks':CHECKS}
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
    if error:sys.exit(1)
