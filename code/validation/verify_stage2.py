#!/usr/bin/env python3
"""Stage-2 independent source-data checks. Does NOT execute MATLAB/Simscape."""
from pathlib import Path
import argparse,hashlib,json,re,zipfile
import numpy as np
import pandas as pd
from scipy.interpolate import PchipInterpolator
ROOT=Path(__file__).resolve().parents[2]
checks=[]
def check(name,condition,detail=''):
    condition=bool(condition);checks.append(dict(check=name,passed=condition,detail=detail))
    if not condition:raise AssertionError(name+': '+detail)
def close(name,a,b,atol=1e-8):
    a=np.asarray(a,float);b=np.asarray(b,float)
    check(name,a.shape==b.shape and np.allclose(a,b,atol=atol,rtol=1e-12,equal_nan=True))
def crossing(x,y,limit,method):
    x=np.asarray(x,float);y=np.maximum.accumulate(np.asarray(y,float))
    if y[0]>limit:return 0.
    if y[-1]<=limit:return float(x[-1])
    j=np.flatnonzero(y>limit)[0];i=j-1
    if method=='lower_step':return x[i]
    if method=='linear':return x[i]+(limit-y[i])*(x[j]-x[i])/(y[j]-y[i])
    if method=='log_linear':return np.exp(np.log(x[i])+(limit-y[i])*(np.log(x[j])-np.log(x[i]))/(y[j]-y[i]))
    uy=np.unique(y);xx=np.array([x[y==u].max() for u in uy])
    return float(np.clip(PchipInterpolator(uy,xx)(limit),x[0],x[-1]))
def main():
    p=ROOT/'data/processed';r=ROOT/'data/results/reference'
    nim=pd.read_csv(p/'nim_benchmark.csv');old=pd.read_csv(r/'serving_capacity_interpolation.csv')
    for row in old.itertuples():
        t=nim[(nim.model_key==row.model_key)&(nim.type_key==row.type_key)].sort_values('concurrency')
        ct=crossing(t.concurrency,t.ttft_ms,row.ttft_limit_ms,row.method)
        ci=crossing(t.concurrency,t.itl_ms,row.itl_limit_ms,row.method)
        close('crossing_'+row.method+'_'+row.model_key+'_'+row.SLO_key+'_'+row.type_key,[ct,ci,min(ct,ci)],[row.Cmax_TTFT,row.Cmax_ITL,row.Cmax])
    C=pd.read_csv(p/'thermal_cases.csv');check('thermal_case_count',len(C)==1158 and C.case_id.is_unique)
    check('no_missing_numeric_inputs',not C.select_dtypes('number').isna().any().any())
    close('wall_relation',C.G_wall,C.k_wall*C.A_wall/C.t_wall,atol=1e-7)
    close('radiation_relation',C.k_rad,C.epsilon_rad*5.670374419e-8,atol=1e-20)
    check('absolute_area_feasibility',np.all(C.A_res1<=C.A_pipe)&np.all(C.A_res3<=C.A_pipe))
    M=pd.read_csv(r/'thermal/map/Fig4b_v3_dense_12h_case_definitions.csv');T=C[C.study=='map']
    for k,v in [('Q_server','Q_server_W'),('P_air_internal','P_air_internal_Pa'),('T_ambient','T_ambient_K'),('h2','h2_W_m2K'),('A2','A2_m2'),('G_wall','G_wall_W_K'),('Q_solar','Q_solar_W')]:
        close('map_source_'+k,T[k],M[v])
    for study,filename in [('duct','thermal_v5_duct_fine_case_definitions.csv'),('robustness','thermal_fig4d_robustness_case_definitions.csv')]:
        T=C[C.study==study];src=pd.read_csv(r/'thermal'/study/filename)
        for k in set(src.columns)&set(C.select_dtypes('number').columns):
            close(study+'_source_'+k,T[k],src[k])
        close(study+'_duration',T.stop_time_s,5000*src.sim_time_scale)
    for study,prefix in [('highload_a','A'),('highload_b','B'),('highload_c','C'),('highload_c2','C2')]:
        T=C[C.study==study];src=pd.read_csv(r/'thermal'/study/(prefix+'_summary.csv'))
        close(study+'_heat',T.Q_server,src.Q_server_W)
        close(study+'_external_UA',T.A2*T.h2,src.UA_ext_W_K)
        close(study+'_duct_area',T.A_pipe,.01*src.duct_scale)
        close(study+'_hydraulic_diameter',T.D_h_pipe,.1*np.sqrt(src.duct_scale))
        if 'A1_m2' in src:close(study+'_internal_area',T.A1,src.A1_m2)
    models=pd.read_csv(ROOT/'models/simscape/model_manifest.csv')
    for row in models.itertuples():
        path=ROOT/'models/simscape'/row.model_file
        check(row.model_file+'_hash',hashlib.sha256(path.read_bytes()).hexdigest()==row.sha256)
        with zipfile.ZipFile(path) as z:
            check(row.model_file+'_zip',z.testzip() is None)
            config=z.read('simulink/configSet0.xml').decode();check(row.model_file+'_stop_time','<P Name="StopTime" Class="char">5000</P>' in config)
            xml='\n'.join(z.read(x).decode('utf-8',errors='replace') for x in z.namelist() if x.endswith('.xml'))
            for signal in ['server_T','chamber_T','radiator_T','P_fan_shaft']:
                check(row.model_file+'_signal_'+signal,signal in xml)
    cp=pd.read_csv(p/'thermal_smoke_checkpoints.csv');raw=pd.read_csv(r/'thermal/robustness/thermal_fig4d_robustness_all_rpm_results.csv')
    for row in cp.itertuples():
        t=raw[(raw.case_id==1)&(raw.w_fan_cmd_rpm==row.rpm)&(raw.sim_success==1)].iloc[0]
        close('smoke_'+str(row.rpm),[row.expected_feasible,row.server_mean_tail_K,row.chamber_mean_tail_K,row.fan_electrical_power_W], [t.feasible,t.server_mean_tail,t.chamber_mean_tail,t.Pfan_elec_est_from_shaft])
    check('smoke_adjacent',np.array_equal(cp.rpm,[2650,2675]))
    # All supplied frozen thermal CSVs remain parseable; the old headerless
    # empty C candidate file is intentionally replaced by reporting from C summary.
    for f in sorted((r/'thermal').rglob('*.csv')):
        t=pd.read_csv(f);check('thermal_csv_'+f.name,len(t.columns)>0)
    # Static file paths and primary MATLAB function names, NOT compilation.
    for f in ROOT.rglob('*.m'):
        text=f.read_text();m=re.search(r'^function\s+(?:\[[^\]]+\]|\w+)\s*=\s*(\w+)\s*\(',text,re.M)
        if not m:m=re.search(r'^function\s+(\w+)\s*\(',text,re.M)
        check('matlab_primary_'+f.stem,m is not None and m[1]==f.stem)
        check('english_'+f.stem,not re.search('[\uac00-\ud7a3]',text))
        check('no_local_paths_'+f.stem,'/mnt/data' not in text and not re.search(r'[A-Za-z]:\\Users\\',text))
    # Explicit safety properties visible in the source, not inferred runtime claims.
    text=(ROOT/'code/thermal/run_thermal_study.m').read_text();check('thermal_execute_default_false',"'Execute',false" in text)
    text=(ROOT/'code/thermal/search_thermal_speed.m').read_text();check('failed_refinement_not_infeasible','indeterminate_refinement' in text and re.search(r'~r\.sim_success\s*\|\|\s*~r\.converged',text) is not None)
    text=(ROOT/'code/thermal/run_thermal_point.m').read_text();check('thermal_no_base_assignment','assignin(' not in text and 'setVariable' in text)
    text=(ROOT/'code/validation/run_monte_carlo_validation.m').read_text();check('mc_default_smoke',"'Mode','smoke'" in text)
    check('no_primary_mc_search','monte_carlo' not in (ROOT/'run_full_reproduction.m').read_text().lower())
    return checks
if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--report',type=Path);a=ap.parse_args();error=None
    try:main()
    except Exception as exc:error=repr(exc)
    out=dict(scope='Python arithmetic/source consistency and static inspection only; MATLAB/Simulink/Simscape not executed',passed=error is None,checks_passed=sum(x['passed'] for x in checks),checks_total=len(checks),error=error,checks=checks)
    if a.report:a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(out,indent=2))
    print(json.dumps({k:v for k,v in out.items() if k!='checks'},indent=2))
    if error:raise SystemExit(1)
