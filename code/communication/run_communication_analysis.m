function out = run_communication_analysis(varargin)
% RUN_COMMUNICATION_ANALYSIS Downlink activity, link budget and radio power.
% Reads current exact N95 and the associated N_A,...,N_E, not old MC outputs.
% Keeps the supplied traffic, free-space link and EARTH component models.
% Fan power is scaled by the stored module fan/IT ratio to 1275 W for Fig. 5d.
% This is not a multi-user scheduler or a joint end-to-end reliability model.
paths=haps_paths;
    p = inputParser;

    % Explicit input paths, independent of the current working directory.
    addParameter(p,'SingleInstanceFile',fullfile(paths.reference,'exact','single_instance_exact.csv'),@(x)ischar(x)||isstring(x));
    addParameter(p,'PkFile',fullfile(paths.processed,'workload_occupancy.csv'),@(x)ischar(x)||isstring(x));
    addParameter(p,'AlphaFile',fullfile(paths.processed,'activity_statistics.csv'),@(x)ischar(x)||isstring(x));
    addParameter(p,'ThermalReferenceFile',fullfile(paths.processed,'thermal_reference.csv'),@(x)ischar(x)||isstring(x));
    addParameter(p,'OutputDir','',@(x)ischar(x)||isstring(x));
    % ---- Fig. 5 traffic model -------------------------------------------
    addParameter(p, 'SelectedSLOKeys', "general", @(x)ischar(x)||isstring(x)||iscellstr(x));
    addParameter(p, 'SLOITLMap', struct('general',100), @isstruct);
    addParameter(p, 'BytesPerToken', [4 6], @(x)isnumeric(x)&&isvector(x)&&all(x>0));
    addParameter(p, 'OverheadFactor', 3, @(x)isnumeric(x)&&isscalar(x)&&x>=1);

    % ---- Reference free-space downlink budget --------------------------
    addParameter(p, 'CarrierHz', 2e9, @(x)isnumeric(x)&&isscalar(x)&&x>0);
    addParameter(p, 'BandwidthHz', 20e6, @(x)isnumeric(x)&&isscalar(x)&&x>0);
    addParameter(p, 'HAPSAltitudeKm', 20, @(x)isnumeric(x)&&isscalar(x)&&x>0);
    addParameter(p, 'DistanceKm', [20 40 60], @(x)isnumeric(x)&&isvector(x)&&all(x>0));
    addParameter(p, 'HAPSAntennaGain_dBi', 20, @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'UEAntennaGain_dBi', 0, @(x)isnumeric(x)&&isscalar(x));
    addParameter(p, 'MiscLoss_dB', 3, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    addParameter(p, 'NoiseFigure_dB', 7, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    addParameter(p, 'LinkMargin_dB', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    % non-ideal-link robustness. Values are sensitivity parameters.
    addParameter(p, 'ImplementationGapSweep_dB', [3 6], ...
        @(x)isnumeric(x)&&isvector(x)&&all(isfinite(x))&&all(x>=0));
    addParameter(p, 'SNRFloorSweep_dB', [-10 -5 0], ...
        @(x)isnumeric(x)&&isvector(x)&&all(isfinite(x)));
    addParameter(p, 'NoiseDensity_dBm_Hz', -174, @(x)isnumeric(x)&&isscalar(x));

    % ---- EARTH reference-envelope options -------------------------------
    addParameter(p, 'EarthReferenceBandwidthMHz', 10, ...
        @(x)isnumeric(x)&&isscalar(x)&&x>0);
    addParameter(p, 'CircuitRateStat', "p95", @(x)ischar(x)||isstring(x));
    addParameter(p, 'CircuitScenarios', ["as_reported","bb_linear_scaled"], ...
        @(x)isstring(x)||iscellstr(x)||ischar(x));
    addParameter(p, 'NTRXSweep', [1 2 4 6], ...
        @(x)isnumeric(x)&&isvector(x)&&all(isfinite(x))&&all(x>=1)&&all(mod(x,1)==0));

    % ---- Fig. 5d payload-level auxiliary parity -------------------------
    addParameter(p, 'ParityModelKey', 'llama33_70b_2xH100_fp8_TP2', ...
        @(x)ischar(x)||isstring(x));
    addParameter(p, 'ParityNormalizationModel', 'llama31_8b_1xH100_fp8_TP1', @(x)ischar(x)||isstring(x));
    addParameter(p, 'ParityITPowerW', 1275, @(x)isnumeric(x)&&isscalar(x)&&x>0);
    addParameter(p, 'GroundCoolingRatios', [0.05 0.10 0.15 0.20 0.30], ...
        @(x)isnumeric(x)&&isvector(x)&&all(x>=0));
    addParameter(p, 'ParityCircuitScenario', "bb_linear_scaled", ...
        @(x)ischar(x)||isstring(x));
    addParameter(p, 'ParityRateStat', "p95", @(x)ischar(x)||isstring(x));

    % ---- General ---------------------------------------------------------
    addParameter(p, 'WriteDistributionCSV', true, @(x)islogical(x)||ismember(x,[0 1]));
    addParameter(p, 'Verbose', true, @(x)islogical(x)||ismember(x,[0 1]));

    parse(p, varargin{:});
    cfg = p.Results;

    cfg.SelectedSLOKeys = string(cfg.SelectedSLOKeys);
    cfg.SelectedSLOKeys = lower(cfg.SelectedSLOKeys(:));
    cfg.BytesPerToken = double(cfg.BytesPerToken(:)).';
    cfg.DistanceKm = double(cfg.DistanceKm(:)).';
    cfg.CircuitScenarios = string(cfg.CircuitScenarios);
    cfg.CircuitScenarios = lower(cfg.CircuitScenarios(:)).';
    cfg.ImplementationGapSweep_dB = unique(double(cfg.ImplementationGapSweep_dB(:)).','stable');
    cfg.SNRFloorSweep_dB = unique(double(cfg.SNRFloorSweep_dB(:)).','stable');
    cfg.NTRXSweep = unique(round(double(cfg.NTRXSweep(:)).'),'stable');

    if any(cfg.DistanceKm < cfg.HAPSAltitudeKm)
        error('All DistanceKm values must be >= HAPSAltitudeKm for this geometry model.');
    end

    outDir = haps_new_output_dir(cfg.OutputDir,'communication');

    % ---------------------------------------------------------------------
    % 1. Read final Fig. 2 / Fig. 3 inputs
    % ---------------------------------------------------------------------
    Tsingle = readtable(haps_require_file(cfg.SingleInstanceFile),'TextType','string');
    Tpk = readtable(haps_require_file(cfg.PkFile),'TextType','string');
    Talpha = readtable(haps_require_file(cfg.AlphaFile),'TextType','string');
    assert_columns(Tsingle,["model_key","display_label","SLO_feasible","N95_exact", ...
        "N_A","N_B","N_C","N_D","N_E"],'SingleInstanceFile');
    assert_columns(Tpk,["Type","ElapsedTimeShare_p_k"],'PkFile');
    assert_columns(Talpha,["Type","alpha_baseline"],'AlphaFile');
    if ~isequal(cfg.SelectedSLOKeys,"general")
        error('HAPS:UnsupportedSLO','The packaged exact input is for the general SLO only.');
    end
    primary=["llama31_8b_1xH100_fp8_TP1";"llama33_70b_2xH100_fp8_TP2"];
    [tf,ix]=ismember(primary,string(Tsingle.model_key));
    if ~all(tf) || numel(unique(Tsingle.model_key))~=height(Tsingle)
        error('HAPS:InvalidRegistry','Require one unique row per primary model.');
    end
    Tsingle=Tsingle(ix,:);
    if any(~haps_logical(Tsingle.SLO_feasible)), error('HAPS:InfeasiblePrimary','A primary model is infeasible.'); end
    [pkBase,alphaBase]=load_workload_inputs(cfg.PkFile,cfg.AlphaFile);
    qBase=pkBase./alphaBase; qBase=qBase/sum(qBase);
    alloc=haps_allocation(max(Tsingle.N95_exact),qBase);
    Tcap=table(primary,string(Tsingle.display_label),repmat("general",2,1), ...
        double(Tsingle.N95_exact),repmat(0.05,2,1), ...
        'VariableNames',{'model_key','model_label','SLO_key','N_95','reliability_threshold'});
    rows=cell(10,5);
    for i=1:2
        Nk=double(Tsingle{i,{'N_A','N_B','N_C','N_D','N_E'}}).';
        validateattributes(Nk,{'numeric'},{'finite','integer','nonnegative'});
        if sum(Nk)~=Tcap.N_95(i) || ~isequal(Nk,alloc(Tcap.N_95(i),:).')
            error('HAPS:PopulationMismatch','Exact Nk does not match the sequential-deficit population path.');
        end
        for k=1:5
            rows((i-1)*5+k,:)={primary(i),string(char('A'+k-1)),pkBase(k),alphaBase(k),Nk(k)};
        end
    end
    Tmix=cell2table(rows,'VariableNames',{'model_key','Type','p_k','alpha_k','registered_users_Nk_at_N95'});

    % ---------------------------------------------------------------------
    % 2. Fig. 5a: exact stochastic active-user distribution and DL rates
    % ---------------------------------------------------------------------
    rateRows = struct([]);
    pmfRows  = struct([]);
    auditRows = struct([]);
    iRate = 0;
    iPmf  = 0;
    iAudit = 0;

    typeOrder = ["A","B","C","D","E"];

    for i = 1:height(Tcap)
        modelKey   = string(Tcap.model_key(i));
        modelLabel = string(Tcap.model_label(i));
        sloKey     = lower(string(Tcap.SLO_key(i)));
        N95        = round(double(Tcap.N_95(i)));

        itl_ms = lookup_slo_itl_ms(sloKey, cfg.SLOITLMap);
        tokenRate_tps = 1000 / itl_ms;

        M = Tmix(string(Tmix.model_key) == modelKey, :);
        if isempty(M)
            error('No registered-user mix rows found for model %s.', modelKey);
        end
        M = order_type_rows(M, typeOrder);

        Nk = round(double(M.registered_users_Nk_at_N95));
        alpha = double(M.alpha_k);
        pk = double(M.p_k);

        if sum(Nk) ~= N95
            error(['N95 mismatch for %s: SingleInstanceFile gives %d but the sum of ' ...
                   'registered_users_Nk_at_N95 is %d.'], modelKey, N95, sum(Nk));
        end

        % Cross-check final Fig. 2 p_k and alpha_k values.
        maxAlphaDiff = 0;
        maxPkDiff = 0;
        for k = 1:numel(typeOrder)
            t = typeOrder(k);
            ia = find(string(Talpha.Type) == t, 1);
            ip = find(string(Tpk.Type) == t, 1);
            if isempty(ia) || isempty(ip)
                error('Type %s is missing from Fig. 2 input files.', t);
            end
            maxAlphaDiff = max(maxAlphaDiff, abs(alpha(k) - double(Talpha.alpha_baseline(ia))));
            maxPkDiff = max(maxPkDiff, abs(pk(k) - double(Tpk.ElapsedTimeShare_p_k(ip))));
        end

        if maxAlphaDiff > 1e-10
            warning('Alpha mismatch for %s: max |delta| = %.3g', modelKey, maxAlphaDiff);
        end
        if maxPkDiff > 1e-10
            warning('p_k mismatch for %s: max |delta| = %.3g', modelKey, maxPkDiff);
        end

        % Exact PMF of total active users = convolution of five Binomials.
        pmfTotal = 1;
        for k = 1:numel(typeOrder)
            pmfK = stable_binomial_pmf(Nk(k), alpha(k));
            pmfTotal = conv(pmfTotal, pmfK);
            pmfTotal = pmfTotal / sum(pmfTotal);
        end
        activeCount = (0:numel(pmfTotal)-1).';
        cdfTotal = cumsum(pmfTotal(:));
        cdfTotal(end) = 1;  % suppress tiny floating-point drift

        meanActive = sum(activeCount .* pmfTotal(:));
        varActive = sum((activeCount - meanActive).^2 .* pmfTotal(:));
        stdActive = sqrt(max(varActive,0));
        meanActiveTheory = sum(Nk .* alpha);

        q50 = discrete_quantile(activeCount, cdfTotal, 0.50);
        q95 = discrete_quantile(activeCount, cdfTotal, 0.95);
        q99 = discrete_quantile(activeCount, cdfTotal, 0.99);

        % Save PMF once per model/SLO (independent of bytes/token).
        if cfg.WriteDistributionCSV
            for j = 1:numel(activeCount)
                iPmf = iPmf + 1;
                pmfRows(iPmf).model_key = modelKey;
                pmfRows(iPmf).model_label = modelLabel;
                pmfRows(iPmf).SLO_key = sloKey;
                pmfRows(iPmf).active_users = activeCount(j);
                pmfRows(iPmf).probability = pmfTotal(j);
                pmfRows(iPmf).cdf = cdfTotal(j);
            end
        end

        for b = cfg.BytesPerToken
            payloadPerActive_bps = tokenRate_tps * b * 8;
            designPerActive_bps  = cfg.OverheadFactor * payloadPerActive_bps;

            iRate = iRate + 1;
            rateRows(iRate).model_key = modelKey;
            rateRows(iRate).model_label = modelLabel;
            rateRows(iRate).SLO_key = sloKey;
            rateRows(iRate).N_95 = N95;
            if ismember('reliability_threshold', Tcap.Properties.VariableNames)
                rateRows(iRate).reliability_threshold = double(Tcap.reliability_threshold(i));
            else
                rateRows(iRate).reliability_threshold = NaN;
            end
            rateRows(iRate).bytes_per_token = b;
            rateRows(iRate).itl_ms = itl_ms;
            rateRows(iRate).token_rate_tps = tokenRate_tps;
            rateRows(iRate).overhead_factor = cfg.OverheadFactor;
            rateRows(iRate).mean_active_users = meanActive;
            rateRows(iRate).mean_active_users_theory = meanActiveTheory;
            rateRows(iRate).std_active_users = stdActive;
            rateRows(iRate).p50_active_users = q50;
            rateRows(iRate).p95_active_users = q95;
            rateRows(iRate).p99_active_users = q99;
            rateRows(iRate).payload_rate_mean_Mbps = meanActive * payloadPerActive_bps / 1e6;
            rateRows(iRate).payload_rate_p50_Mbps = q50 * payloadPerActive_bps / 1e6;
            rateRows(iRate).payload_rate_p95_Mbps = q95 * payloadPerActive_bps / 1e6;
            rateRows(iRate).payload_rate_p99_Mbps = q99 * payloadPerActive_bps / 1e6;
            rateRows(iRate).design_rate_mean_Mbps = meanActive * designPerActive_bps / 1e6;
            rateRows(iRate).design_rate_p50_Mbps = q50 * designPerActive_bps / 1e6;
            rateRows(iRate).design_rate_p95_Mbps = q95 * designPerActive_bps / 1e6;
            rateRows(iRate).design_rate_p99_Mbps = q99 * designPerActive_bps / 1e6;
            rateRows(iRate).all_registered_active_design_rate_Mbps = ...
                N95 * designPerActive_bps / 1e6;
        end

        iAudit = iAudit + 1;
        auditRows(iAudit).model_key = modelKey;
        auditRows(iAudit).SLO_key = sloKey;
        auditRows(iAudit).N95_from_capacity = N95;
        auditRows(iAudit).sum_registered_mix_N95 = sum(Nk);
        auditRows(iAudit).max_abs_alpha_diff_vs_Fig2 = maxAlphaDiff;
        auditRows(iAudit).max_abs_pk_diff_vs_Fig2 = maxPkDiff;
        auditRows(iAudit).mean_active_exact = meanActive;
        auditRows(iAudit).mean_active_theory = meanActiveTheory;
        auditRows(iAudit).mean_active_abs_diff = abs(meanActive - meanActiveTheory);
        auditRows(iAudit).population_source = "single_instance_exact.csv N95_exact and N_A...N_E";
        auditRows(iAudit).population_method = "deterministic independent-Binomial exact-under-model";
    end

    RateSummary = struct2table(rateRows);
    if cfg.WriteDistributionCSV
        ActivePMF = struct2table(pmfRows);
    else
        ActivePMF = table();
    end
    InputAudit = struct2table(auditRows);

    % ---------------------------------------------------------------------
    % 3. Fig. 5b: robust rate -> SNR -> payload-bearing radiated Tx power
    % ---------------------------------------------------------------------
    linkRows = struct([]);
    iLink = 0;

    B_Hz = cfg.BandwidthHz;
    f_Hz = cfg.CarrierHz;
    c0 = 299792458;
    noise_dBm = cfg.NoiseDensity_dBm_Hz + 10*log10(B_Hz) + cfg.NoiseFigure_dB;

    LinkScenarios = build_link_robustness_scenarios( ...
        cfg.ImplementationGapSweep_dB, cfg.SNRFloorSweep_dB);

    rateStats = ["mean","p95","p99","all_active"];

    for i = 1:height(RateSummary)
        for sIdx = 1:numel(rateStats)
            stat = rateStats(sIdx);
            switch stat
                case "mean"
                    R_Mbps = RateSummary.design_rate_mean_Mbps(i);
                    activeUsersStat = RateSummary.mean_active_users(i);
                case "p95"
                    R_Mbps = RateSummary.design_rate_p95_Mbps(i);
                    activeUsersStat = RateSummary.p95_active_users(i);
                case "p99"
                    R_Mbps = RateSummary.design_rate_p99_Mbps(i);
                    activeUsersStat = RateSummary.p99_active_users(i);
                case "all_active"
                    R_Mbps = RateSummary.all_registered_active_design_rate_Mbps(i);
                    activeUsersStat = RateSummary.N_95(i);
            end

            R_bps = R_Mbps * 1e6;
            eta_bphz = R_bps / B_Hz;
            snrLin = expm1(log(2) * eta_bphz);  % stable 2^eta - 1
            if snrLin <= 0
                shannonSNR_dB = -Inf;
            else
                shannonSNR_dB = 10*log10(snrLin);
            end

            for sc = 1:height(LinkScenarios)
                gap_dB = LinkScenarios.implementation_gap_dB(sc);
                floor_dB = LinkScenarios.snr_floor_dB(sc);

                unflooredSNR_dB = shannonSNR_dB + gap_dB;
                if isfinite(floor_dB)
                    usedSNR_dB = max(unflooredSNR_dB, floor_dB);
                    floorActive = floor_dB > unflooredSNR_dB;
                else
                    usedSNR_dB = unflooredSNR_dB;
                    floorActive = false;
                end

                for d_km = cfg.DistanceKm
                    d_m = d_km * 1e3;
                    FSPL_dB = 20*log10(4*pi*d_m*f_Hz/c0);
                    requiredRx_dBm = noise_dBm + usedSNR_dB;
                    payloadTx_dBm = requiredRx_dBm + FSPL_dB + cfg.MiscLoss_dB ...
                        - cfg.HAPSAntennaGain_dBi - cfg.UEAntennaGain_dBi ...
                        + cfg.LinkMargin_dB;
                    payloadTx_W = 10.^((payloadTx_dBm - 30)/10);

                    horiz_km = sqrt(max(d_km^2 - cfg.HAPSAltitudeKm^2, 0));
                    elev_deg = asind(min(1, cfg.HAPSAltitudeKm / d_km));

                    iLink = iLink + 1;
                    linkRows(iLink).model_key = RateSummary.model_key(i);
                    linkRows(iLink).model_label = RateSummary.model_label(i);
                    linkRows(iLink).SLO_key = RateSummary.SLO_key(i);
                    linkRows(iLink).bytes_per_token = RateSummary.bytes_per_token(i);
                    linkRows(iLink).rate_stat = stat;
                    linkRows(iLink).active_users_for_rate_stat = activeUsersStat;
                    linkRows(iLink).design_total_rate_Mbps = R_Mbps;
                    linkRows(iLink).bandwidth_MHz = B_Hz/1e6;
                    linkRows(iLink).required_SE_bphz = eta_bphz;
                    linkRows(iLink).link_scenario = LinkScenarios.link_scenario(sc);
                    linkRows(iLink).scenario_class = LinkScenarios.scenario_class(sc);
                    linkRows(iLink).shannon_SNR_dB = shannonSNR_dB;
                    linkRows(iLink).implementation_gap_dB = gap_dB;
                    linkRows(iLink).snr_floor_dB = floor_dB;
                    linkRows(iLink).unfloored_required_SNR_dB = unflooredSNR_dB;
                    linkRows(iLink).used_required_SNR_dB = usedSNR_dB;
                    linkRows(iLink).snr_floor_active = floorActive;
                    linkRows(iLink).carrier_GHz = f_Hz/1e9;
                    linkRows(iLink).haps_altitude_km = cfg.HAPSAltitudeKm;
                    linkRows(iLink).slant_distance_km = d_km;
                    linkRows(iLink).approx_horizontal_radius_km = horiz_km;
                    linkRows(iLink).approx_elevation_deg = elev_deg;
                    linkRows(iLink).FSPL_dB = FSPL_dB;
                    linkRows(iLink).noise_dBm = noise_dBm;
                    linkRows(iLink).haps_antenna_gain_dBi = cfg.HAPSAntennaGain_dBi;
                    linkRows(iLink).ue_antenna_gain_dBi = cfg.UEAntennaGain_dBi;
                    linkRows(iLink).misc_loss_dB = cfg.MiscLoss_dB;
                    linkRows(iLink).link_margin_dB = cfg.LinkMargin_dB;
                    linkRows(iLink).required_payload_Rx_dBm = requiredRx_dBm;
                    linkRows(iLink).payload_bearing_radiated_Tx_dBm = payloadTx_dBm;
                    linkRows(iLink).payload_bearing_radiated_Tx_W = payloadTx_W;
                    linkRows(iLink).Tx_interpretation = ...
                        "payload-bearing DL radiation only; control/reference radiation excluded";
                end
            end
        end
    end

    LinkBudget = struct2table(linkRows);

    % ---------------------------------------------------------------------
    % 4. Fig. 5c: radio electrical power + N_TRX sensitivity
    % ---------------------------------------------------------------------
    Earth = earth_2012_component_reference();
    circuitRows = struct([]);
    iCirc = 0;

    rateStatForCircuit = lower(string(cfg.CircuitRateStat));
    Lmain = LinkBudget(lower(string(LinkBudget.rate_stat)) == rateStatForCircuit, :);
    if isempty(Lmain)
        error('CircuitRateStat "%s" is not present in LinkBudget.', rateStatForCircuit);
    end

    B_MHz = B_Hz/1e6;
    Bscale = B_MHz / cfg.EarthReferenceBandwidthMHz;

    for i = 1:height(Lmain)
        PtxPayload_W = double(Lmain.payload_bearing_radiated_Tx_W(i));

        for cIdx = 1:numel(cfg.CircuitScenarios)
            scenario = lower(string(cfg.CircuitScenarios(cIdx)));

            for e = 1:height(Earth)
                switch scenario
                    case "as_reported"
                        rfUsed_W = Earth.RF_total_Pdc_W(e);
                        bbUsed_W = Earth.BB_total_Pdc_W(e);
                    case "bb_linear_scaled"
                        rfUsed_W = Earth.RF_total_Pdc_W(e); % no simple RF law assumed
                        bbUsed_W = Earth.BB_total_Pdc_W(e) * Bscale;
                    otherwise
                        error('Unknown CircuitScenario: %s', scenario);
                end

                etaPA = Earth.PA_efficiency(e);
                dcdcLoss = Earth.DCDC_loss_fraction(e);
                pFixedCore_perTRX_W = rfUsed_W + bbUsed_W;

                for ntrx = cfg.NTRXSweep
                    % Total payload-bearing radiation is divided equally among
                    % active chains. With equal PA efficiency, aggregate PA DC
                    % remains Ptx/eta; fixed RF+BB power grows with N_TRX.
                    pTxPerTRX_W = PtxPayload_W / ntrx;
                    pPaDcTotal_W = PtxPayload_W / etaPA;
                    pPaDcPerTRX_W = pTxPerTRX_W / etaPA;
                    pFixedCoreTotal_W = ntrx * pFixedCore_perTRX_W;

                    pCommBeforeDcdc_W = pPaDcTotal_W + pFixedCoreTotal_W;
                    pComm_W = pCommBeforeDcdc_W / (1-dcdcLoss);
                    pFixedAfterDcdc_W = pFixedCoreTotal_W / (1-dcdcLoss);
                    pPaAfterDcdc_W = pPaDcTotal_W / (1-dcdcLoss);

                    isNative = ntrx == Earth.native_NTRX(e);
                    withinPerTrxPmax = pTxPerTRX_W <= Earth.Pmax_W_per_TRX(e);
                    withinTotalPmax = PtxPayload_W <= ntrx*Earth.Pmax_W_per_TRX(e);

                    if pTxPerTRX_W > 0
                        headroomPerTrx_dB = 10*log10(Earth.Pmax_W_per_TRX(e)/pTxPerTRX_W);
                    else
                        headroomPerTrx_dB = Inf;
                    end

                    iCirc = iCirc + 1;
                    circuitRows(iCirc).model_key = Lmain.model_key(i);
                    circuitRows(iCirc).model_label = Lmain.model_label(i);
                    circuitRows(iCirc).SLO_key = Lmain.SLO_key(i);
                    circuitRows(iCirc).bytes_per_token = Lmain.bytes_per_token(i);
                    circuitRows(iCirc).rate_stat = Lmain.rate_stat(i);
                    circuitRows(iCirc).design_total_rate_Mbps = Lmain.design_total_rate_Mbps(i);
                    circuitRows(iCirc).link_scenario = Lmain.link_scenario(i);
                    circuitRows(iCirc).scenario_class = Lmain.scenario_class(i);
                    circuitRows(iCirc).used_required_SNR_dB = Lmain.used_required_SNR_dB(i);
                    circuitRows(iCirc).slant_distance_km = Lmain.slant_distance_km(i);
                    circuitRows(iCirc).payload_bearing_radiated_Tx_W = PtxPayload_W;
                    circuitRows(iCirc).earth_bs_type = Earth.BS_type(e);
                    circuitRows(iCirc).circuit_scenario = scenario;
                    circuitRows(iCirc).analysis_NTRX = ntrx;
                    circuitRows(iCirc).native_EARTH_NTRX = Earth.native_NTRX(e);
                    circuitRows(iCirc).is_native_EARTH_NTRX = isNative;
                    circuitRows(iCirc).earth_reference_year = 2012;
                    circuitRows(iCirc).earth_reference_bandwidth_MHz = cfg.EarthReferenceBandwidthMHz;
                    circuitRows(iCirc).analysis_bandwidth_MHz = B_MHz;
                    circuitRows(iCirc).RF_reference_Pdc_W_per_TRX = Earth.RF_total_Pdc_W(e);
                    circuitRows(iCirc).BB_reference_Pdc_W_per_TRX = Earth.BB_total_Pdc_W(e);
                    circuitRows(iCirc).RF_used_Pdc_W_per_TRX = rfUsed_W;
                    circuitRows(iCirc).BB_used_Pdc_W_per_TRX = bbUsed_W;
                    circuitRows(iCirc).PA_efficiency_reference = etaPA;
                    circuitRows(iCirc).payload_Tx_W_per_TRX = pTxPerTRX_W;
                    circuitRows(iCirc).PA_DC_dynamic_W_per_TRX = pPaDcPerTRX_W;
                    circuitRows(iCirc).PA_DC_dynamic_total_W = pPaDcTotal_W;
                    circuitRows(iCirc).DCDC_loss_fraction = dcdcLoss;
                    circuitRows(iCirc).fixed_RF_BB_before_DCDC_W_total = pFixedCoreTotal_W;
                    circuitRows(iCirc).fixed_RF_BB_after_DCDC_W_total = pFixedAfterDcdc_W;
                    circuitRows(iCirc).PA_after_DCDC_W_total = pPaAfterDcdc_W;
                    circuitRows(iCirc).P_comm_W = pComm_W;
                    circuitRows(iCirc).fixed_power_fraction = pFixedAfterDcdc_W / pComm_W;
                    circuitRows(iCirc).Pmax_W_per_TRX = Earth.Pmax_W_per_TRX(e);
                    circuitRows(iCirc).payload_Tx_within_per_TRX_Pmax = withinPerTrxPmax;
                    circuitRows(iCirc).payload_Tx_within_total_node_Pmax = withinTotalPmax;
                    circuitRows(iCirc).payload_Tx_headroom_dB_per_TRX = headroomPerTrx_dB;
                    circuitRows(iCirc).EARTH_cooling_excluded = true;
                    circuitRows(iCirc).EARTH_main_supply_excluded = true;
                    circuitRows(iCirc).PA_model_note = ...
                        "payload Tx / EARTH full-load eta; fixed RF+BB scales with N_TRX";
                    circuitRows(iCirc).communication_power_interpretation = ...
                        "EARTH-derived terrestrial reference envelope; not exact HAPS radio hardware";
                end
            end
        end
    end

    CircuitPower = struct2table(circuitRows);

    % ---------------------------------------------------------------------
    % 5. Fig. 5d: payload-level auxiliary-power parity across robustness
    % ---------------------------------------------------------------------
    Thermal=readtable(haps_require_file(cfg.ThermalReferenceFile),'TextType','string');
    assert_columns(Thermal,["reference_IT_power_W","fan_electrical_power_W"],'ThermalReferenceFile');
    if height(Thermal)~=1, error('HAPS:ThermalReference','Require exactly one thermal reference row.'); end
    refIT=double(Thermal.reference_IT_power_W(1));
    refFan=double(Thermal.fan_electrical_power_W(1));
    validateattributes(refIT,{'numeric'},{'finite','scalar','positive'});
    validateattributes(refFan,{'numeric'},{'finite','scalar','nonnegative'});
    fanPower_W=refFan/refIT*cfg.ParityITPowerW;
    fanSource="stored module fan/IT ratio; proportional resizing or replication";

    parityModel = string(cfg.ParityModelKey);
    parityScenario = lower(string(cfg.ParityCircuitScenario));
    parityRateStat = lower(string(cfg.ParityRateStat));

    Psel = CircuitPower(string(CircuitPower.model_key) == parityModel & ...
                        lower(string(CircuitPower.circuit_scenario)) == parityScenario & ...
                        lower(string(CircuitPower.rate_stat)) == parityRateStat, :);
    if isempty(Psel)
        error(['No CircuitPower rows matched ParityModelKey=%s, scenario=%s, ' ...
                 'rateStat=%s.'], ...
                 parityModel, parityScenario, parityRateStat);
    else
        parityRows = cell(height(Psel)*numel(cfg.GroundCoolingRatios),1);
        iParity = 0;
        for i = 1:height(Psel)
            for r = cfg.GroundCoolingRatios(:).'
                PgroundCool_W = r * cfg.ParityITPowerW;
                PcommBE_W = PgroundCool_W - fanPower_W;

                newRow = make_parity_row(Psel(i,:), ...
                    r, cfg.ParityITPowerW, fanPower_W, fanSource, ...
                    PgroundCool_W, PcommBE_W);
                iParity = iParity + 1;
                parityRows{iParity} = newRow;
            end
        end
        AuxiliaryParity = struct2table(vertcat(parityRows{:}));
        AuxiliaryParity.traffic_reference_model = string(AuxiliaryParity.model_key);
        AuxiliaryParity.normalization_reference_model = repmat(string(cfg.ParityNormalizationModel),height(AuxiliaryParity),1);
        AuxiliaryParity.normalization_IT_power_W = AuxiliaryParity.IT_power_W;
    end

    % ---------------------------------------------------------------------
    % 6. All outputs use current exact populations
    % ---------------------------------------------------------------------


    % ---------------------------------------------------------------------
    % 7. Write outputs (separate names; default separate folder)
    % ---------------------------------------------------------------------
    writetable(RateSummary, fullfile(outDir, 'downlink_rates.csv'));
    if cfg.WriteDistributionCSV
        writetable(ActivePMF, fullfile(outDir, 'active_user_pmf.csv'));
    end
    writetable(LinkBudget, fullfile(outDir, 'link_budget.csv'));
    writetable(LinkScenarios, fullfile(outDir, 'link_scenarios.csv'));
    writetable(CircuitPower, fullfile(outDir, 'radio_power.csv'));
    if ~isempty(AuxiliaryParity)
        writetable(AuxiliaryParity, fullfile(outDir, 'auxiliary_parity.csv'));
    else
        writetable(table(), fullfile(outDir, 'auxiliary_parity.csv'));
    end
    writetable(InputAudit, fullfile(outDir, 'input_audit.csv'));

    out = struct();
    out.Config = cfg;
    out.RateSummary = RateSummary;
    out.ActiveUserPMF = ActivePMF;
    out.LinkScenarioDefinitions = LinkScenarios;
    out.LinkBudgetRobustness = LinkBudget;
    out.EarthReference = Earth;
    out.CircuitPowerNTRX = CircuitPower;
    out.AuxiliaryParity = AuxiliaryParity;
    out.InputAudit = InputAudit;
    out.output_dir = outDir;
    out.ReferenceFanPower_W = fanPower_W;
    out.ReferenceFanSource = fanSource;

    save(fullfile(outDir, 'communication_workspace.mat'), 'out');

    if cfg.Verbose
        fprintf('\n============================================================\n');
        fprintf('Fig. 5 communication-power robustness analysis complete\n');
        fprintf('============================================================\n');
        fprintf('Output folder: %s\n', outDir);
        fprintf('DL only | bytes/token = %s | overhead factor = %.3g\n', ...
            mat2str(cfg.BytesPerToken), cfg.OverheadFactor);
        fprintf('Distances [km] = %s\n', mat2str(cfg.DistanceKm));
        fprintf('Implementation-gap sensitivity [dB] = %s\n', ...
            mat2str(cfg.ImplementationGapSweep_dB));
        fprintf('SNR-floor stress tests [dB] = %s\n', mat2str(cfg.SNRFloorSweep_dB));
        fprintf('N_TRX sensitivity = %s\n', mat2str(cfg.NTRXSweep));
        fprintf('Reference fan power = %.6f W (%s)\n', fanPower_W, fanSource);

        fprintf('\nFig5a summary:\n');
        disp(RateSummary(:, {'model_label','SLO_key','bytes_per_token','N_95', ...
            'mean_active_users','p95_active_users','p99_active_users', ...
            'design_rate_mean_Mbps','design_rate_p95_Mbps','design_rate_p99_Mbps'}));

        fprintf('\nFig5b P95 / 6-byte robustness summary:\n');
        showLink = LinkBudget(lower(string(LinkBudget.rate_stat))=="p95" & ...
            LinkBudget.bytes_per_token==max(cfg.BytesPerToken), :);
        disp(showLink(:, {'model_label','link_scenario','slant_distance_km', ...
            'design_total_rate_Mbps','shannon_SNR_dB','used_required_SNR_dB', ...
            'payload_bearing_radiated_Tx_W'}));

        fprintf('\nFig5c 20-km / 6-byte / bb-scaled / Shannon circuit summary:\n');
        showCirc = CircuitPower( ...
            lower(string(CircuitPower.circuit_scenario))=="bb_linear_scaled" & ...
            string(CircuitPower.link_scenario)=="shannon_baseline" & ...
            CircuitPower.slant_distance_km==min(cfg.DistanceKm) & ...
            CircuitPower.bytes_per_token==max(cfg.BytesPerToken), :);
        disp(showCirc(:, {'model_label','earth_bs_type','analysis_NTRX', ...
            'payload_bearing_radiated_Tx_W','P_comm_W','fixed_power_fraction'}));

        fprintf('============================================================\n\n');
    end
end

% =========================================================================
% Local helpers
% =========================================================================

function assert_columns(T, requiredNames, label)
    have = string(T.Properties.VariableNames);
    missing = requiredNames(~ismember(requiredNames, have));
    if ~isempty(missing)
        error('%s is missing columns: %s', label, strjoin(missing, ', '));
    end
end

function M = order_type_rows(M, typeOrder)
    idx = zeros(numel(typeOrder),1);
    for k = 1:numel(typeOrder)
        hit = find(string(M.Type) == typeOrder(k));
        if numel(hit) ~= 1
            error('Expected exactly one row for Type %s; found %d.', typeOrder(k), numel(hit));
        end
        idx(k) = hit;
    end
    M = M(idx,:);
end

function itl_ms = lookup_slo_itl_ms(sloKey, sloMap)
    fieldName = matlab.lang.makeValidName(char(lower(string(sloKey))));
    if ~isfield(sloMap, fieldName)
        error(['No ITL mapping is defined for SLO_key="%s". ' ...
               'Pass SLOITLMap, e.g. struct(''general'',100,''itl_stringent'',40).'], ...
               string(sloKey));
    end
    itl_ms = double(sloMap.(fieldName));
    if ~(isscalar(itl_ms) && isfinite(itl_ms) && itl_ms > 0)
        error('Invalid ITL value for SLO_key="%s".', string(sloKey));
    end
end

function pmf = stable_binomial_pmf(n, prob)
    n = round(double(n));
    prob = double(prob);
    if n < 0 || prob < 0 || prob > 1
        error('Invalid binomial parameters n=%g, p=%g.', n, prob);
    end
    if prob == 0
        pmf = [1; zeros(n,1)];
        return;
    elseif prob == 1
        pmf = [zeros(n,1); 1];
        return;
    end

    j = (0:n).';
    logpmf = gammaln(n+1) - gammaln(j+1) - gammaln(n-j+1) ...
        + j*log(prob) + (n-j)*log1p(-prob);
    shift = max(logpmf);
    pmf = exp(logpmf - shift);
    pmf = pmf / sum(pmf);
end

function q = discrete_quantile(x, cdf, target)
    idx = find(cdf >= target, 1, 'first');
    if isempty(idx)
        idx = numel(x);
    end
    q = x(idx);
end

function Earth = earth_2012_component_reference()
% EARTH D2.3 Table 7, 2012 SOTA, per-TRX component references.
% Cooling and main-supply values are kept only as metadata and are NOT used
% in the HAPS payload-boundary P_comm calculation.

    BS_type = ["Macro";"RRH";"Micro";"Pico";"Femto/Home"];
    Pmax_W_per_TRX = [39.8; 20.0; 6.3; 0.13; 0.10];
    PA_Pdc_max_W = [102.6; 51.5; 22.1; 1.6; 1.0];
    PA_efficiency = [0.388; 0.388; 0.285; 0.080; 0.052];
    RF_total_Pdc_W = [10.9; 10.9; 5.4; 0.7; 0.4];
    BB_total_Pdc_W = [14.8; 14.8; 13.6; 1.5; 1.2];
    DCDC_loss_fraction = [0.060; 0.060; 0.064; 0.080; 0.080];
    Cooling_loss_fraction = [0.090; 0.000; 0.000; 0.000; 0.000];
    MainSupply_loss_fraction = [0.070; 0.070; 0.072; 0.100; 0.100];
    native_NTRX = [6;6;2;2;2];

    Earth = table(BS_type, Pmax_W_per_TRX, PA_Pdc_max_W, PA_efficiency, ...
        RF_total_Pdc_W, BB_total_Pdc_W, DCDC_loss_fraction, ...
        Cooling_loss_fraction, MainSupply_loss_fraction, native_NTRX);
end

function row = make_parity_row(PselRow, groundRatio, pIT_W, ...
        fanPower_W, fanSource, pGroundCool_W, pCommBE_W)

    pComm_W = double(PselRow.P_comm_W(1));
    pHapsAux_W = fanPower_W + pComm_W;
    margin_W = pGroundCool_W - pHapsAux_W;
    breakEvenCoolingRatio = pHapsAux_W / pIT_W;

    row.model_key = PselRow.model_key(1);
    row.model_label = PselRow.model_label(1);
    row.SLO_key = PselRow.SLO_key(1);
    row.bytes_per_token = PselRow.bytes_per_token(1);
    row.rate_stat = PselRow.rate_stat(1);
    row.link_scenario = PselRow.link_scenario(1);
    row.scenario_class = PselRow.scenario_class(1);
    row.used_required_SNR_dB = PselRow.used_required_SNR_dB(1);
    row.slant_distance_km = PselRow.slant_distance_km(1);
    row.payload_bearing_radiated_Tx_W = PselRow.payload_bearing_radiated_Tx_W(1);
    row.earth_bs_type = PselRow.earth_bs_type(1);
    row.circuit_scenario = PselRow.circuit_scenario(1);
    row.analysis_NTRX = PselRow.analysis_NTRX(1);
    row.native_EARTH_NTRX = PselRow.native_EARTH_NTRX(1);
    row.is_native_EARTH_NTRX = PselRow.is_native_EARTH_NTRX(1);
    row.fixed_power_fraction = PselRow.fixed_power_fraction(1);
    row.Pmax_W_per_TRX = PselRow.Pmax_W_per_TRX(1);
    row.payload_Tx_within_per_TRX_Pmax = PselRow.payload_Tx_within_per_TRX_Pmax(1);
    row.payload_Tx_within_total_node_Pmax = PselRow.payload_Tx_within_total_node_Pmax(1);
    row.IT_power_W = pIT_W;
    row.fan_power_W = fanPower_W;
    row.fan_power_source = fanSource;
    row.communication_power_W = pComm_W;
    row.HAPS_auxiliary_power_W = pHapsAux_W;
    row.break_even_ground_cooling_ratio = breakEvenCoolingRatio;
    row.break_even_ground_cooling_percent = 100*breakEvenCoolingRatio;
    row.ground_cooling_ratio = groundRatio;
    row.ground_cooling_power_W = pGroundCool_W;
    row.break_even_communication_power_W = pCommBE_W;
    row.parity_margin_W = margin_W;
    row.HAPS_aux_lower_than_ground_cooling = margin_W >= 0;
end

function S = build_link_robustness_scenarios(gapSweep_dB, floorSweep_dB)
% Build mutually interpretable link scenarios rather than a full Cartesian
% product. This keeps the output compact and makes each sensitivity isolate
% one modeling change from the Shannon baseline.

    gapSweep_dB = gapSweep_dB(gapSweep_dB~=0);
    nRows = 1+numel(gapSweep_dB)+numel(floorSweep_dB);
    names = strings(nRows,1); classes = strings(nRows,1);
    gaps = zeros(nRows,1); floors = -inf(nRows,1); notes = strings(nRows,1);
    names(1) = "shannon_baseline"; classes(1) = "lower_bound";
    notes(1) = "Ideal Shannon payload-bearing reference; 5-dB link margin is still applied";
    iRow = 1;
    for g = gapSweep_dB(:).'
        iRow = iRow+1;
        names(iRow) = "impl_gap_" + string(strrep(sprintf('%g',g),'.','p')) + "dB";
        classes(iRow) = "implementation_gap"; gaps(iRow) = g;
        notes(iRow) = "Shannon-required SNR plus implementation-gap sensitivity";
    end
    for f = floorSweep_dB(:).'
        iRow = iRow+1;
        if f<0, tag="m"+string(strrep(sprintf('%g',abs(f)),'.','p'));
        else, tag=string(strrep(sprintf('%g',f),'.','p')); end
        names(iRow) = "snr_floor_"+tag+"dB"; floors(iRow) = f;
        classes(iRow) = "snr_floor_stress_test";
        notes(iRow) = "Stress test: required SNR cannot fall below the specified floor";
    end

    S = table(names, classes, gaps, floors, notes, ...
        'VariableNames', {'link_scenario','scenario_class', ...
        'implementation_gap_dB','snr_floor_dB','scenario_note'});
end

