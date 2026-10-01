function out = plot_release_figures(varargin)
% PLOT_RELEASE_FIGURES Render downstream numerical panels from explicit CSVs.
% Covers Fig. 3d-e, Fig. 5a-d, Fig. 6a-e, and Supplementary Figs. 2-4.
% The numerical sources and definitions are retained. This is a clean export
% layout, not a pixel-identical reconstruction of manually composed figures.
% No probabilities or capacity thresholds are estimated by this plotter.
p0=haps_paths;p=inputParser;
addParameter(p,'ExactDir',fullfile(p0.reference,'exact'),@(x)ischar(x)||isstring(x));
addParameter(p,'CommunicationDir',fullfile(p0.reference,'communication'),@(x)ischar(x)||isstring(x));
addParameter(p,'PayloadDir',fullfile(p0.reference,'payload'),@(x)ischar(x)||isstring(x));
addParameter(p,'MappingAlphaFile',fullfile(p0.processed,'mapping_activity.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'MappingFile',fullfile(p0.reference,'mapping','mapping_sensitivity_exact.csv'),@(x)ischar(x)||isstring(x));
addParameter(p,'ValidationDir',fullfile(p0.reference,'validation'),@(x)ischar(x)||isstring(x));
addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
addParameter(p,'Visible','off',@(x)ismember(string(x),["on","off"]));
parse(p,varargin{:});o=p.Results;outDir=haps_new_output_dir(o.OutputDir,'figures');
S=readcsv(fullfile(o.ExactDir,'single_instance_exact.csv'));
A=readcsv(fullfile(o.ExactDir,'platform_assignment_exact.csv'));
F=readcsv(fullfile(o.ExactDir,'fleet_sizing_exact.csv'));
V=readcsv(fullfile(o.ExactDir,'primary_overload_curve.csv'));
D=readcsv(fullfile(o.CommunicationDir,'downlink_rates.csv'));
L=readcsv(fullfile(o.CommunicationDir,'link_budget.csv'));
C=readcsv(fullfile(o.CommunicationDir,'radio_power.csv'));
B=readcsv(fullfile(o.CommunicationDir,'auxiliary_parity.csv'));
H=readcsv(fullfile(o.PayloadDir,'configuration_efficiency.csv'));
P=readcsv(fullfile(o.PayloadDir,'deployment_limits.csv'));
G=readcsv(fullfile(o.PayloadDir,'shared_host_scaling.csv'));
M=readcsv(o.MappingFile);
primary=["llama31_8b_1xH100_fp8_TP1";"llama33_70b_2xH100_fp8_TP2"];
[tf,ix]=ismember(primary,string(S.model_key));if ~all(tf),error('HAPS:PrimaryRows','Missing primary models.');end
SP=S(ix,:);exports=strings(0,1);

f=newfig(1000,410);tl=tiledlayout(f,1,2,'TileSpacing','compact');
for i=1:2
    ax=nexttile(tl);r=V(string(V.model_key)==primary(i),:);r=sortrows(r,'N');
    plot(ax,r.N_over_Nharm,100*r.P_overload_exact,'-o');hold(ax,'on');
    yline(ax,5,'--','5% criterion');xline(ax,SP.N95_exact(i)/SP.Nharm(i),'--','N_{95}');
    xlabel(ax,'User-equivalent population / N_{harm}');ylabel(ax,'Overload probability (%)');
    title(ax,SP.display_label(i),'Interpreter','none');grid(ax,'on');
end
savepanel(f,'fig03d_overload_probability',V);
f=newfig(650,460);ax=axes(f);bar(ax,[SP.Nharm,SP.N95_exact]);
set(ax,'XTick',1:2,'XTickLabel',cellstr(SP.display_label),'TickLabelInterpreter','none');
ylabel(ax,'User-equivalent capacity');legend(ax,{'Nominal N_{harm}','Exact N_{95}'},'Location','best');grid(ax,'on');
savepanel(f,'fig03e_nominal_and_reliable_capacity',SP);

% Fig. 5a: population normalization and traffic use the same current exact row.
rate4=zeros(2,1);rate6=zeros(2,1);active=zeros(2,1);n=zeros(2,1);
for i=1:2
    lo=D(string(D.model_key)==primary(i)&D.bytes_per_token==4,:);
    hi=D(string(D.model_key)==primary(i)&D.bytes_per_token==6,:);
    if height(lo)~=1||height(hi)~=1,error('HAPS:RateRows','Require unique 4/6-byte rows.');end
    rate4(i)=lo.design_rate_p95_Mbps;rate6(i)=hi.design_rate_p95_Mbps;
    active(i)=hi.p95_active_users;n(i)=hi.N_95;
end
f=newfig(1100,450);tl=tiledlayout(f,1,2,'TileSpacing','compact');ax=nexttile(tl);
barh(ax,100*active./n);set(ax,'YTick',1:2,'YTickLabel',cellstr(SP.display_label),'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'P95 active fraction of user equivalents (%)');title(ax,'P95 simultaneous activity');grid(ax,'on');
for i=1:2,text(ax,100*active(i)/n(i)+.05,i,sprintf('%d / %d',active(i),n(i)));end
xlim(ax,[0,5]);ax=nexttile(tl);hold(ax,'on');
for i=1:2,plot(ax,[rate4(i),rate6(i)],[i,i],'-','HandleVisibility','off');end
plot(ax,rate4,1:2,'o','DisplayName','4 bytes/token');plot(ax,rate6,1:2,'s','DisplayName','6 bytes/token');
set(ax,'YTick',1:2,'YTickLabel',cellstr(SP.display_label),'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'P95 downlink design rate (Mbit/s)');ylim(ax,[.5,2.5]);title(ax,'P95 downlink design rate');grid(ax,'on');legend(ax,'Location','best');
savepanel(f,'fig05a_activity_and_downlink_rate',D);
f=newfig(720,500);ax=axes(f);hold(ax,'on');
for i=1:2
    for sc=["shannon_baseline","impl_gap_6dB"]
        t=L(string(L.model_key)==primary(i)&L.bytes_per_token==6&string(L.rate_stat)=="p95"&string(L.link_scenario)==sc,:);
        t=sortrows(t,'slant_distance_km');plot(ax,t.slant_distance_km,t.payload_bearing_radiated_Tx_W,'-o', ...
            'DisplayName',SP.display_label(i)+" / "+replace(sc,"_"," "));
    end
end
t=L(string(L.model_key)==primary(1)&L.bytes_per_token==6&string(L.rate_stat)=="p95"&string(L.link_scenario)=="snr_floor_0dB",:);
t=sortrows(t,'slant_distance_km');plot(ax,t.slant_distance_km,t.payload_bearing_radiated_Tx_W,'-s','DisplayName','0-dB SNR floor');
set(ax,'YScale','log');xlabel(ax,'HAPS-user slant distance (km)');ylabel(ax,'Payload-bearing radiated downlink power (W)');
yline(ax,1,'--','1 W','HandleVisibility','off');grid(ax,'on');legend(ax,'Location','best','Interpreter','none');
savepanel(f,'fig05b_radiated_downlink_power',L);
radioMask=string(C.model_key)==primary(2)&C.bytes_per_token==6&string(C.rate_stat)=="p95"& ...
    C.slant_distance_km==20&string(C.link_scenario)=="snr_floor_0dB"&string(C.circuit_scenario)=="bb_linear_scaled";
R=C(radioMask,:);f=newfig(740,500);ax=axes(f);hold(ax,'on');
classes=["Macro","Micro","Pico","Femto/Home"];
for cl=classes
    t=sortrows(R(string(R.earth_bs_type)==cl,:),'analysis_NTRX');label=cl;if cl=="Macro",label="Macro/RRH";end
    plot(ax,t.analysis_NTRX,t.P_comm_W,'-o','DisplayName',label);
    plot(ax,t.analysis_NTRX,t.fixed_RF_BB_after_DCDC_W_total,':','HandleVisibility','off');
    native=haps_logical(t.is_native_EARTH_NTRX);plot(ax,t.analysis_NTRX(native),t.P_comm_W(native),'*','HandleVisibility','off');
end
set(ax,'YScale','log');xticks(ax,[1,2,4,6]);xlabel(ax,'Active transceiver chains');ylabel(ax,'Radio electrical power (W)');
legend(ax,'Location','best','Interpreter','none');grid(ax,'on');savepanel(f,'fig05c_radio_electrical_power',R);
mask=string(B.model_key)==primary(2)&B.bytes_per_token==6&string(B.rate_stat)=="p95"& ...
    B.slant_distance_km==20&string(B.link_scenario)=="snr_floor_0dB"&string(B.circuit_scenario)=="bb_linear_scaled"&abs(B.ground_cooling_ratio-.05)<1e-12;
BE=B(mask,:);f=newfig(740,500);ax=axes(f);hold(ax,'on');
for cl=classes
    t=sortrows(BE(string(BE.earth_bs_type)==cl,:),'analysis_NTRX');label=cl;if cl=="Macro",label="Macro/RRH";end
    plot(ax,t.analysis_NTRX,t.break_even_ground_cooling_percent,'-o','DisplayName',label);
    native=haps_logical(t.is_native_EARTH_NTRX);plot(ax,t.analysis_NTRX(native),t.break_even_ground_cooling_percent(native),'*','HandleVisibility','off');
end
xticks(ax,[1,2,4,6]);yline(ax,5,'--','Illustrative 5% reference','HandleVisibility','off');
xlabel(ax,'Active transceiver chains');ylabel(ax,'Break-even cooling overhead (% of IT)');
legend(ax,'Location','best','Interpreter','none');grid(ax,'on');savepanel(f,'fig05d_auxiliary_power_parity',BE);

f=newfig(1000,490);ax=axes(f);y=double(H.serving_efficiency_user_eq_per_kW);y(~isfinite(y))=0;bar(ax,y);
set(ax,'XTick',1:height(H),'XTickLabel',cellstr(H.display_label),'TickLabelInterpreter','none');xtickangle(ax,28);
ylabel(ax,'Exact user equivalents per IT kW');grid(ax,'on');
for i=1:height(H)
    if haps_logical(H.SLO_feasible(i)),txt=sprintf('N95 = %d',H.N95_exact(i));else,txt='SLO-infeasible';end
    text(ax,i,y(i)+60,txt,'Rotation',0,'HorizontalAlignment','center','FontSize',8);
end
savepanel(f,'fig06a_serving_efficiency',H);
f=newfig(800,500);ax=axes(f);hold(ax,'on');
scatter(ax,H.engineering_mass_kg,H.IT_power_kW,50,'DisplayName','Serving configurations');
plot(ax,G.engineering_mass_kg,G.IT_power_kW,'-d','DisplayName','L40S shared-host reference');
for i=1:height(H),text(ax,H.engineering_mass_kg(i)+.5,H.IT_power_kW(i),H.display_label(i),'Interpreter','none','FontSize',8);end
xlabel(ax,'Reference IT-system payload mass (kg)');ylabel(ax,'IT payload power (kW)');grid(ax,'on');legend(ax,'Location','best');
savepanel(f,'fig06b_payload_power_mass',H);writetable(G,fullfile(outDir,'fig06b_shared_host_values.csv'));
f=newfig(1150,450);tl=tiledlayout(f,1,2,'TileSpacing','compact');
for plat=["Sunglider","Stratobus"]
    ax=nexttile(tl);t=P(string(P.platform)==plat,:);bar(ax,t.deployable_instances);hold(ax,'on');
    plot(ax,1:height(t),t.IT_only_instances,'d','DisplayName','IT-only limit');
    set(ax,'XTick',1:height(t),'XTickLabel',cellstr(t.display_label),'TickLabelInterpreter','none');xtickangle(ax,35);
    ylabel(ax,'Deployable serving instances');title(ax,plat);grid(ax,'on');
end
savepanel(f,'fig06c_deployable_instances',P);
f=newfig(1120,480);tl=tiledlayout(f,1,2,'TileSpacing','compact');
for plat=["Sunglider","Stratobus"]
    ax=nexttile(tl);t=A(string(A.platform)==plat,:);yy=(1:height(t)).';
    barh(ax,yy,t.NHAPS95_pooled_exact);hold(ax,'on');
    plot(ax,t.linear_mN95_exact,yy,'d','DisplayName','Linear mN95');
    labels=string(t.display_label)+" (m="+string(t.m_instances)+")";
    set(ax,'YTick',yy,'YTickLabel',cellstr(labels),'YDir','reverse','TickLabelInterpreter','none');
    for i=1:height(t),text(ax,t.NHAPS95_pooled_exact(i),i,sprintf(' %d',t.NHAPS95_pooled_exact(i)),'FontSize',8);end
    xlabel(ax,'Reliability-aware user equivalents per HAPS');title(ax,plat);grid(ax,'on');xlim(ax,[0,max(t.NHAPS95_pooled_exact)*1.20]);
end
savepanel(f,'fig06d_platform_capacity',A);
f=newfig(760,500);ax=axes(f);hold(ax,'on');
for plat=["Sunglider","Stratobus"]
    t=F(string(F.platform)==plat,:);caps=unique(t.best_exact_NHAPS95);
    if numel(caps)~=1,error('HAPS:FleetInput','Inconsistent best capacities.');end
    xx=(0:max(t.target_user_equivalents)).';stairs(ax,xx,ceil(xx/caps),'DisplayName',plat);
    plot(ax,t.target_user_equivalents,t.minimum_active_HAPS_count,'o','HandleVisibility','off');
end
xlabel(ax,'Target user-equivalent demand');ylabel(ax,'Minimum active HAPS count');legend(ax,'Location','best');grid(ax,'on');
savepanel(f,'fig06e_fleet_sizing',F);

% Supplementary mapping and assignment sensitivities are exact source exports.
mapOrder=["baseline","overlap_distance","b_over_c","c_over_b","global_distance"];
Y=zeros(5,2);mapLabels=strings(5,1);
for i=1:5
    for j=1:2
        t=M(string(M.mapping_key)==mapOrder(i)&string(M.model_key)==primary(j),:);
        if height(t)~=1,error('HAPS:MappingRows','Missing or duplicated mapping/model row.');end
        Y(i,j)=t.N95_exact;mapLabels(i)=string(t.mapping_label);
    end
end
f=newfig(1000,470);ax=axes(f);bar(ax,Y);set(ax,'XTick',1:5,'XTickLabel',cellstr(mapLabels),'TickLabelInterpreter','none');xtickangle(ax,25);
ylabel(ax,'Exact user-equivalent capacity N95');legend(ax,cellstr(SP.display_label),'Location','best','Interpreter','none');grid(ax,'on');
savepanel(f,'supp_fig02_mapping_sensitivity',M);
t=A(A.m_instances>1,:);f=newfig(1100,460);ax=axes(f);
barh(ax,[t.NHAPS95_static_exact,t.linear_mN95_exact,t.NHAPS95_pooled_exact]);
set(ax,'YTick',1:height(t),'YTickLabel',cellstr(string(t.platform)+": "+string(t.display_label)), ...
    'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'Reliability-aware user equivalents per HAPS');legend(ax,{'Static balanced','Linear mN95','Pooled'},'Location','best');grid(ax,'on');
savepanel(f,'supp_fig03_assignment_sensitivity',t);
f=newfig(1060,460);tl=tiledlayout(f,1,2,'TileSpacing','compact');mcAll=table();
for i=1:2
    family=["8b","70b"];family=family(i);
    mc=readcsv(fullfile(o.ValidationDir,char(family+"_pooled_mc_curve.csv")));
    ex=readcsv(fullfile(o.ValidationDir,char(family+"_exact_threshold_neighborhood.csv")));
    ax=nexttile(tl);plot(ax,ex.N,100*ex.P_overload_exact,'-','DisplayName','Exact-under-model');hold(ax,'on');
    errorbar(ax,mc.N,mc.P_overload_pooled_percent, ...
        mc.P_overload_pooled_percent-mc.CI95_low_percent,mc.CI95_high_percent-mc.P_overload_pooled_percent, ...
        'o','DisplayName','2M-snapshot Monte Carlo');
    yline(ax,5,'--','5% criterion','HandleVisibility','off');xline(ax,SP.N95_exact(i),'--','Exact N95','HandleVisibility','off');
    xlim(ax,SP.N95_exact(i)+[-3,3]);xlabel(ax,'User-equivalent population');ylabel(ax,'Overload probability (%)');
    title(ax,SP.display_label(i),'Interpreter','none');grid(ax,'on');legend(ax,'Location','best');
    mc.model_key=repmat(primary(i),height(mc),1);mcAll=[mcAll;mc]; %#ok<AGROW>
end
savepanel(f,'supp_fig04_mc_validation',mcAll);
export_downstream_supplementary_tables('ExactDir',o.ExactDir,'PayloadDir',o.PayloadDir, ...
    'MappingAlphaFile',o.MappingAlphaFile, ...
    'MappingFile',o.MappingFile,'ValidationDir',o.ValidationDir,'OutputDir',fullfile(outDir,'supplementary_tables'));
out=struct('output_dir',outDir,'panel_names',exports);
    function t=readcsv(path)
        t=readtable(haps_require_file(path),'TextType','string');
    end
    function f0=newfig(width,height0)
        f0=figure('Color','w','Visible',char(o.Visible),'Units','pixels','Position',[80,80,width,height0]);
    end
    function savepanel(f0,name,values)
        prefix=fullfile(outDir,name);writetable(values,[prefix '_values.csv']);
        exportgraphics(f0,[prefix '.pdf'],'ContentType','vector');
        exportgraphics(f0,[prefix '.png'],'Resolution',300);savefig(f0,[prefix '.fig']);
        exports(end+1)=string(name);close(f0);
    end
end
