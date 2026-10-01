"""Independent arithmetic checks for the Stage-1 MATLAB migration.

This module does not run MATLAB or Simscape. It mirrors the supplied baseline
traffic/link/payload equations using NumPy/SciPy. Archived exact results remain
separate from newly derived communication and payload tables. Python packages
are optional for users who reproduce the analysis in MATLAB.
"""
from __future__ import annotations
from pathlib import Path
import math
import numpy as np
import pandas as pd
from scipy.stats import binom

PRIMARY = ['llama31_8b_1xH100_fp8_TP1','llama33_70b_2xH100_fp8_TP2']
TYPES = list('ABCDE')

def logical(x):
    if pd.api.types.is_bool_dtype(x): return x.astype(bool)
    s=x.astype(str).str.lower().str.strip()
    if not s.isin(['0','1','true','false','0.0','1.0']).all():
        raise ValueError('Invalid boolean CSV values')
    return s.isin(['1','true','1.0'])

def workload(root: Path):
    s=pd.read_csv(root/'data/processed/workload_occupancy.csv').set_index('Type').loc[TYPES]
    a=pd.read_csv(root/'data/processed/activity_statistics.csv').set_index('Type').loc[TYPES]
    pk=s.ElapsedTimeShare_p_k.to_numpy(float);pk/=pk.sum()
    alpha=a.alpha_baseline.to_numpy(float)
    q=pk/alpha;q/=q.sum()
    return pk,alpha,q

def allocation(max_n:int,q:np.ndarray):
    if max_n<0 or int(max_n)!=max_n:raise ValueError('Population must be a nonnegative integer')
    q=np.asarray(q,float);q=q/q.sum();counts=np.zeros(5,dtype=int);out=np.zeros((max_n,5),dtype=int)
    for i in range(1,max_n+1):
        deficit=i*q-counts;idx=np.flatnonzero(abs(deficit-deficit.max())<1e-12)
        chosen=idx[np.argmax(q[idx])];counts[chosen]+=1;out[i-1]=counts
    return out

def total_active_pmf(nk:np.ndarray,alpha:np.ndarray):
    pmf=np.ones(1)
    for n,p in zip(nk,alpha):
        part=binom.pmf(np.arange(int(n)+1),int(n),p)
        part/=part.sum();pmf=np.convolve(pmf,part)
    pmf/=pmf.sum()
    return pmf

def exact_probability(nk,alpha,cmax):
    """The supplied 2+2+1 exact-under-model calculation in independent Python."""
    import itertools
    nk=np.asarray(nk,int);alpha=np.asarray(alpha,float);cmax=np.asarray(cmax,float)
    caps=np.minimum(nk,np.floor(cmax+64*np.spacing(np.maximum(1,abs(cmax))))).astype(int)
    within=binom.cdf(caps,nk,alpha)
    xs=[];ps=[]
    for i in range(5):
        x=np.arange(caps[i]+1);p=binom.pmf(x,nk[i],alpha[i]);mask=p>0
        xs.append(x[mask]);ps.append(p[mask])
    best=None
    for s in range(5):
        r=[i for i in range(5) if i!=s]
        for a,b in [((r[0],r[1]),(r[2],r[3])),((r[0],r[2]),(r[1],r[3])),((r[0],r[3]),(r[1],r[2]))]:
            na=len(xs[a[0]])*len(xs[a[1]]);nb=len(xs[b[0]])*len(xs[b[1]])
            qp,op=(a,b) if na>=nb else (b,a);cost=len(xs[s])*min(na,nb)
            if best is None or cost<best[0]:best=(cost,s,qp,op)
    _,s,qp,op=best
    def pair(pair):
        a,b=pair
        # MATLAB column-major ordering is retained before sorting equal loads.
        return ((xs[a][:,None]/cmax[a]+xs[b][None,:]/cmax[b]).ravel(order='F'),
                (ps[a][:,None]*ps[b][None,:]).ravel(order='F'))
    lq,pq=pair(qp);ind=np.argsort(lq,kind='stable');lq=lq[ind];pq=pq[ind]
    cdf=np.cumsum(pq);total=cdf[-1] if len(cdf) else 0
    lo,po=pair(op);joint=0.
    for x,p in zip(xs[s],ps[s]):
        t=1-x/cmax[s]-lo;t=t+128*np.spacing(np.maximum(1,abs(t)))
        ix=np.searchsorted(lq,t,side='right');cdf_pad=np.r_[0,cdf]
        tail=np.clip(total-cdf_pad[ix],0,total)
        joint+=p*np.sum(po*tail)
    return float(np.clip(1-np.prod(within)+joint,0,1))

def derive_communication(root:Path):
    single=pd.read_csv(root/'data/results/reference/exact/single_instance_exact.csv').set_index('model_key')
    _,alpha,q=workload(root);rates=[];pmfs=[];audits=[]
    for key in PRIMARY:
        row=single.loc[key];n=int(row.N95_exact);nk=row[['N_'+k for k in TYPES]].to_numpy(int)
        if not np.array_equal(allocation(n,q)[-1],nk):raise ValueError('Exact population path mismatch')
        pmf=total_active_pmf(nk,alpha);x=np.arange(n+1);cdf=np.cumsum(pmf)
        mean=float(x@pmf);std=float(np.sqrt(((x-mean)**2)@pmf))
        q50,q95,q99=[int(np.searchsorted(cdf,t)) for t in [.5,.95,.99]]
        pmfs.append(pd.DataFrame({'model_key':key,'model_label':row.display_label,'SLO_key':'general','active_users':x,'probability':pmf,'cdf':cdf}))
        for b in [4,6]:
            rr=dict(model_key=key,model_label=row.display_label,SLO_key='general',N_95=n,reliability_threshold=.05,bytes_per_token=b,itl_ms=100,token_rate_tps=10,overhead_factor=3,mean_active_users=mean,mean_active_users_theory=float(nk@alpha),std_active_users=std,p50_active_users=q50,p95_active_users=q95,p99_active_users=q99)
            for stat,val in [('mean',mean),('p50',q50),('p95',q95),('p99',q99)]:
                rr['payload_rate_'+stat+'_Mbps']=val*10*b*8/1e6
                rr['design_rate_'+stat+'_Mbps']=val*10*b*8*3/1e6
            rr['all_registered_active_design_rate_Mbps']=n*10*b*8*3/1e6;rates.append(rr)
        audits.append(dict(model_key=key,SLO_key='general',N95_from_capacity=n,sum_registered_mix_N95=int(nk.sum()),max_abs_alpha_diff_vs_Fig2=0,max_abs_pk_diff_vs_Fig2=0,mean_active_exact=mean,mean_active_theory=float(nk@alpha),mean_active_abs_diff=abs(mean-nk@alpha),population_source='single_instance_exact.csv N95_exact and N_A...N_E',population_method='deterministic independent-Binomial exact-under-model'))
    rates=pd.DataFrame(rates);sc=pd.read_csv(root/'data/processed/link_scenarios.csv')
    links=[];band=20e6;noise=-174+10*np.log10(band)+7
    for _,r in rates.iterrows():
        for stat in ['mean','p95','p99','all_active']:
            rate=r['all_registered_active_design_rate_Mbps'] if stat=='all_active' else r['design_rate_'+stat+'_Mbps']
            active=r.N_95 if stat=='all_active' else r[stat+'_active_users']
            se=rate*1e6/band;snr=10*np.log10(np.expm1(np.log(2)*se))
            for _,scenario in sc.iterrows():
                gap=scenario.implementation_gap_dB;floor=scenario.snr_floor_dB;unfloored=snr+gap;used=max(unfloored,floor)
                for dist in [20,40,60]:
                    fspl=20*np.log10(4*np.pi*dist*1e3*2e9/299792458);rx=noise+used;txdbm=rx+fspl+3-20+5;tx=10**((txdbm-30)/10)
                    links.append(dict(model_key=r.model_key,model_label=r.model_label,SLO_key='general',bytes_per_token=r.bytes_per_token,rate_stat=stat,active_users_for_rate_stat=active,design_total_rate_Mbps=rate,bandwidth_MHz=20,required_SE_bphz=se,link_scenario=scenario.link_scenario,scenario_class=scenario.scenario_class,shannon_SNR_dB=snr,implementation_gap_dB=gap,snr_floor_dB=floor,unfloored_required_SNR_dB=unfloored,used_required_SNR_dB=used,snr_floor_active=floor>unfloored,carrier_GHz=2,haps_altitude_km=20,slant_distance_km=dist,approx_horizontal_radius_km=np.sqrt(max(dist**2-20**2,0)),approx_elevation_deg=np.degrees(np.arcsin(20/dist)),FSPL_dB=fspl,noise_dBm=noise,haps_antenna_gain_dBi=20,ue_antenna_gain_dBi=0,misc_loss_dB=3,link_margin_dB=5,required_payload_Rx_dBm=rx,payload_bearing_radiated_Tx_dBm=txdbm,payload_bearing_radiated_Tx_W=tx,Tx_interpretation='payload-bearing DL radiation only; control/reference radiation excluded'))
    links=pd.DataFrame(links);radios=[]
    earth=[('Macro',39.8,.388,10.9,14.8,.060,6),('RRH',20,.388,10.9,14.8,.060,6),('Micro',6.3,.285,5.4,13.6,.064,2),('Pico',.13,.080,.7,1.5,.080,2),('Femto/Home',.10,.052,.4,1.2,.080,2)]
    for _,r in links[links.rate_stat=='p95'].iterrows():
        for mode in ['as_reported','bb_linear_scaled']:
            for cls,pmax,eta,rf,bb,loss,native in earth:
                bbused=bb*(2 if mode=='bb_linear_scaled' else 1)
                for ntrx in [1,2,4,6]:
                    tx=r.payload_bearing_radiated_Tx_W;pa=tx/eta;fixed=ntrx*(rf+bbused);pc=(fixed+pa)/(1-loss)
                    radios.append(dict(model_key=r.model_key,model_label=r.model_label,SLO_key='general',bytes_per_token=r.bytes_per_token,rate_stat=r.rate_stat,design_total_rate_Mbps=r.design_total_rate_Mbps,link_scenario=r.link_scenario,scenario_class=r.scenario_class,used_required_SNR_dB=r.used_required_SNR_dB,slant_distance_km=r.slant_distance_km,payload_bearing_radiated_Tx_W=tx,earth_bs_type=cls,circuit_scenario=mode,analysis_NTRX=ntrx,native_EARTH_NTRX=native,is_native_EARTH_NTRX=ntrx==native,earth_reference_year=2012,earth_reference_bandwidth_MHz=10,analysis_bandwidth_MHz=20,RF_reference_Pdc_W_per_TRX=rf,BB_reference_Pdc_W_per_TRX=bb,RF_used_Pdc_W_per_TRX=rf,BB_used_Pdc_W_per_TRX=bbused,PA_efficiency_reference=eta,payload_Tx_W_per_TRX=tx/ntrx,PA_DC_dynamic_W_per_TRX=pa/ntrx,PA_DC_dynamic_total_W=pa,DCDC_loss_fraction=loss,fixed_RF_BB_before_DCDC_W_total=fixed,fixed_RF_BB_after_DCDC_W_total=fixed/(1-loss),PA_after_DCDC_W_total=pa/(1-loss),P_comm_W=pc,fixed_power_fraction=fixed/(fixed+pa),Pmax_W_per_TRX=pmax,payload_Tx_within_per_TRX_Pmax=tx/ntrx<=pmax,payload_Tx_within_total_node_Pmax=tx<=ntrx*pmax,payload_Tx_headroom_dB_per_TRX=10*np.log10(pmax/(tx/ntrx)),EARTH_cooling_excluded=True,EARTH_main_supply_excluded=True,PA_model_note='payload Tx / EARTH full-load eta; fixed RF+BB scales with N_TRX',communication_power_interpretation='EARTH-derived terrestrial reference envelope; not exact HAPS radio hardware'))
    radios=pd.DataFrame(radios);parity=[]
    th=pd.read_csv(root/'data/processed/thermal_reference.csv').iloc[0];it=1275;fan=th.fan_electrical_power_W/th.reference_IT_power_W*it
    select=radios[(radios.model_key==PRIMARY[1])&(radios.circuit_scenario=='bb_linear_scaled')]
    fields=['model_key','model_label','SLO_key','bytes_per_token','rate_stat','link_scenario','scenario_class','used_required_SNR_dB','slant_distance_km','payload_bearing_radiated_Tx_W','earth_bs_type','circuit_scenario','analysis_NTRX','native_EARTH_NTRX','is_native_EARTH_NTRX','fixed_power_fraction','Pmax_W_per_TRX','payload_Tx_within_per_TRX_Pmax','payload_Tx_within_total_node_Pmax']
    for _,r in select.iterrows():
        for ground in [.05,.1,.15,.2,.3]:
            pc=r.P_comm_W;aux=fan+pc;margin=ground*it-aux
            rr={k:r[k] for k in fields};rr.update(IT_power_W=it,fan_power_W=fan,fan_power_source='stored module fan/IT ratio; proportional resizing or replication',communication_power_W=pc,HAPS_auxiliary_power_W=aux,break_even_ground_cooling_ratio=aux/it,break_even_ground_cooling_percent=100*aux/it,ground_cooling_ratio=ground,ground_cooling_power_W=ground*it,break_even_communication_power_W=ground*it-fan,parity_margin_W=margin,HAPS_aux_lower_than_ground_cooling=margin>=0);parity.append(rr)
    parity=pd.DataFrame(parity)
    parity['traffic_reference_model']=parity['model_key']
    parity['normalization_reference_model']='llama31_8b_1xH100_fp8_TP1'
    parity['normalization_IT_power_W']=parity['IT_power_W']
    return {'downlink_rates.csv':rates,'active_user_pmf.csv':pd.concat(pmfs,ignore_index=True),'input_audit.csv':pd.DataFrame(audits),'link_scenarios.csv':sc,'link_budget.csv':links,'radio_power.csv':radios,'auxiliary_parity.csv':pd.DataFrame(parity)}

def derive_payload(root:Path,radio:pd.DataFrame):
    s=pd.read_csv(root/'data/results/reference/exact/single_instance_exact.csv');a=pd.read_csv(root/'data/results/reference/exact/platform_assignment_exact.csv')
    mass=pd.read_csv(root/'data/processed/engineering_mass_allocations.csv').set_index('model_key')
    p=pd.read_csv(root/'data/processed/platform_envelopes.csv');th=pd.read_csv(root/'data/processed/thermal_reference.csv').iloc[0]
    h=pd.read_csv(root/'data/processed/shared_host_parameters.csv').iloc[0];ratio=th.fan_electrical_power_W/th.reference_IT_power_W
    sel=radio[(radio.model_key==PRIMARY[1])&(radio.rate_stat=='p95')&(radio.bytes_per_token==6)&(radio.slant_distance_km==20)&(radio.link_scenario=='snr_floor_0dB')&(radio.circuit_scenario=='bb_linear_scaled')&(radio.earth_bs_type=='Pico')&(radio.analysis_NTRX==1)]
    assert len(sel)==1;radio_w=float(sel.iloc[0].P_comm_W);cfg=[];deploy=[]
    for _,r in s.iterrows():
        m=float(mass.loc[r.model_key].engineering_mass_kg);ok=bool(r.SLO_feasible)
        cfg.append(dict(model_key=r.model_key,display_label=r.display_label,SLO_feasible=ok,IT_power_kW=r.IT_power_kW,engineering_mass_kg=m,exact_registry_mass_kg=r.allocated_mass_kg,N95_exact=r.N95_exact,serving_efficiency_user_eq_per_kW=r.N95_exact/r.IT_power_kW,Cmix=r.Cmix,Nharm=r.Nharm,N95_over_Nharm=r.N95_exact/r.Nharm))
    for _,plat in p.iterrows():
        ml=plat.payload_mass_limit_kg;pl=plat.payload_power_limit_kW*1000
        for _,r in s.iterrows():
            if r.model_key==h.model_key:fm,um,fw,uw,cap=h.host_mass_kg,h.gpu_mass_kg,h.host_power_kW*1000,h.gpu_power_kW*1000,int(h.max_gpu_count)
            else:fm,um,fw,uw,cap=0,float(mass.loc[r.model_key].engineering_mass_kg),0,r.IT_power_kW*1000,np.inf
            rm=max(0,math.floor((ml-fm)/um));ri=max(0,math.floor((pl-fw)/uw));ra=max(0,math.floor(((pl-radio_w)/(1+ratio)-fw)/uw))
            itonly=min(rm,ri,cap);actual=min(rm,ra,cap);ok=bool(r.SLO_feasible)
            bind='+'.join(k for k,v in zip(['mass','power','server_gpu_cap'],[rm,ra,cap]) if v==min(rm,ra,cap))
            if not ok:actual=itonly=0;bind='slo_infeasible'
            it=fan=total=mt=0;linear=pool=static=np.nan
            if actual:
                it=fw+actual*uw;fan=it*ratio;total=it+fan+radio_w;mt=fm+actual*um;linear=actual*r.N95_exact
                row=a[(a.platform==plat.platform_name)&(a.model_key==r.model_key)]
                assert len(row)==1 and row.iloc[0].m_instances==actual
                pool=row.iloc[0].NHAPS95_pooled_exact;static=row.iloc[0].NHAPS95_static_exact
            deploy.append(dict(platform=plat.platform_name,model_key=r.model_key,display_label=r.display_label,SLO_feasible=ok,uncapped_mass_bound=rm,uncapped_IT_power_bound=ri,uncapped_aux_power_bound=ra,host_gpu_cap=cap,IT_only_instances=itonly,deployable_instances=actual,binding_constraint=bind,deployed_mass_kg=mt,deployed_IT_power_W=it,deployed_fan_power_W=fan,radio_reserve_W=radio_w,total_payload_power_W=total,linear_mN95_reference=linear,NHAPS95_pooled_exact=pool,NHAPS95_static_exact=static))
    n=np.arange(1,int(h.max_gpu_count)+1);n95=s.set_index('model_key').loc[h.model_key].N95_exact
    host=pd.DataFrame(dict(gpu_count=n,engineering_mass_kg=h.host_mass_kg+n*h.gpu_mass_kg,IT_power_kW=h.host_power_kW+n*h.gpu_power_kW,linear_mN95_reference=n*n95))
    return {'configuration_efficiency.csv':pd.DataFrame(cfg),'deployment_limits.csv':pd.DataFrame(deploy),'shared_host_scaling.csv':host}
