clear; clc; close all;

%% 1. Simulation Parameters
% Frequencies
freqList = [4.7e9, 28e9];
freqNames = ["FR1 (4.7 GHz)", "FR2 (28 GHz)"];

% Transmit Power Configuration (Realistic Operation)
% FR1: 60W -> 10*log10(60000) ≈ 47.78 dBm
% FR2: 2W (Max Limit) -> 10*log10(2000) ≈ 33.01 dBm
txPowerList_dBm = [10*log10(60*1000), 10*log10(2*1000)]; 

% 5G NR Numerology (Bandwidth & SCS)
% FR1 (100MHz): SCS 30kHz -> 273 RBs
% FR2 (400MHz): SCS 120kHz -> 264 RBs
scsList = [30, 120]; 
nrbList = [273, 264];

ueNoiseFigure = 7; % UE Noise Figure (dB)

% Antenna Array Dimensions
ueAntSize = [2 2]; 
bsAntSize = [4 4]; 

% Locations
bsPosition1 = [37.455715, 127.133562]; % BS1 - Gachon Univ
bsPosition2 = [37.4528, 127.1097];     % BS2 - Seoul Airport

% Orientations
bsArrayOrientation1 = [-30 0].';
bsArrayOrientation2 = [-30 0].';
ueArrayOrientation = [180 45].';

% UE Deployment Configuration
numUEs = 30;          
stepDist = 15;        
dists = (1:numUEs) * stepDist; 

% Ray Tracing Config
reflectionOrder = 1;

%% 2. Generate UE Coordinates
dirStandard = 90 - bsArrayOrientation1(1); 
[ueLats1, ueLons1] = reckon(bsPosition1(1), bsPosition1(2), dists, dirStandard, wgs84Ellipsoid);
[ueLats2, ueLons2] = reckon(bsPosition2(1), bsPosition2(2), dists, dirStandard, wgs84Ellipsoid);

%% 3. Viewer Setup
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    try
        viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam_map.osm");
    catch
        viewer = siteviewer("Basemap","openstreetmap");
    end
end

%% 4. Main Simulation Loop (SNR Calculation)
snrResults = zeros(length(freqList), 2, numUEs);

for fIdx = 1:length(freqList)
    fc = freqList(fIdx);
    fName = freqNames(fIdx);
    
    % Current frequency params
    txPower = txPowerList_dBm(fIdx);
    scs = scsList(fIdx);
    nrb = nrbList(fIdx);
    
    fprintf('\n--- Analyzing %s ---\n', fName);
    fprintf('  Tx Power: %.2f dBm (%.0f W), SCS: %d kHz, BW: %d MHz\n', ...
        txPower, 10^((txPower-30)/10), scs, nrb*12*scs/1000);
    
    % Define BS Sites
    bsSite1 = txsite("Name","BS1 (Gachon)", "Latitude",bsPosition1(1), "Longitude", bsPosition1(2), ...
        "AntennaAngle",bsArrayOrientation1(1:2), "AntennaHeight",30, "TransmitterFrequency",fc);
    bsSite2 = txsite("Name","BS2 (Seoul Air)", "Latitude",bsPosition2(1), "Longitude", bsPosition2(2), ...
        "AntennaAngle",bsArrayOrientation2(1:2), "AntennaHeight",30, "TransmitterFrequency",fc);
    
    % Define UE Sites
    ueSites1 = repmat(rxsite, 1, numUEs);
    ueSites2 = repmat(rxsite, 1, numUEs);
    
    for i = 1:numUEs
        ueSites1(i) = rxsite("Name",sprintf("UE1-%dm", dists(i)), ...
            "Latitude",ueLats1(i), "Longitude",ueLons1(i), ...
            "AntennaHeight",1, "AntennaAngle",ueArrayOrientation(1:2));
        ueSites2(i) = rxsite("Name",sprintf("UE2-%dm", dists(i)), ...
            "Latitude",ueLats2(i), "Longitude",ueLons2(i), ...
            "AntennaHeight",1, "AntennaAngle",ueArrayOrientation(1:2));
    end
    
    if fIdx == 1
        show(bsSite1); show(bsSite2);
        show(ueSites1); show(ueSites2);
        try; view(viewer, bsPosition1(1), bsPosition1(2)+0.005); catch; end
    end
    
    % Ray Tracing
    fprintf('  Performing Ray Tracing...\n');
    pm = propagationModel("raytracing","Method","sbr","MaxNumReflections",reflectionOrder,"MaxNumDiffractions",0);
    rays1_cell = raytrace(bsSite1, ueSites1, pm, "Type","pathloss");
    rays2_cell = raytrace(bsSite2, ueSites2, pm, "Type","pathloss");
    
    % Calculate SNR
    fprintf('  Calculating SNR...\n');
    for u = 1:numUEs
        if iscell(rays1_cell), r1=rays1_cell(u); else, r1=rays1_cell(u); end
        snrResults(fIdx, 1, u) = calculateLinkSNR(r1, fc, txPower, ueNoiseFigure, bsAntSize, ueAntSize, bsArrayOrientation1, ueArrayOrientation, scs, nrb);
    end
    
    for u = 1:numUEs
        if iscell(rays2_cell), r2=rays2_cell(u); else, r2=rays2_cell(u); end
        snrResults(fIdx, 2, u) = calculateLinkSNR(r2, fc, txPower, ueNoiseFigure, bsAntSize, ueAntSize, bsArrayOrientation2, ueArrayOrientation, scs, nrb);
    end
    fprintf('  Done.\n');
end

%% 5. Plot SNR Results
figure('Name', 'SNR vs Distance', 'Position', [100 500 1000 400]);
t = tiledlayout(1,2);

% Subplot 1: BS1 Gachon (SNR)
nexttile;
plot(dists, squeeze(snrResults(1, 1, :)), '-o', 'LineWidth', 2, 'DisplayName', 'FR1 (4.7G, 60W)');
hold on;
plot(dists, squeeze(snrResults(2, 1, :)), '-s', 'LineWidth', 2, 'DisplayName', 'FR2 (28G, 2W)');
grid on;
title('BS1 (Complex): SNR');
xlabel('Distance (m)'); ylabel('SNR (dB)');
legend('Location','best');
ylim([-20 80]); 

% Subplot 2: BS2 Seoul Airport (SNR)
nexttile;
plot(dists, squeeze(snrResults(1, 2, :)), '-o', 'LineWidth', 2, 'DisplayName', 'FR1 (4.7G, 60W)');
hold on;
plot(dists, squeeze(snrResults(2, 2, :)), '-s', 'LineWidth', 2, 'DisplayName', 'FR2 (28G, 2W)');
grid on;
title('BS2 (Open): SNR');
xlabel('Distance (m)'); ylabel('SNR (dB)');
legend('Location','best');
ylim([-20 80]); 

sgtitle('SNR Analysis (FR1 vs FR2)');

%% 6. Calculate & Plot Throughput (Added Section)
fprintf('\n--- Calculating Throughput (Shannon Capacity) ---\n');

% Initialize Capacity Results
capacityResults = zeros(size(snrResults)); % [Freq, BS, UE]

for fIdx = 1:length(freqList)
    % Calculate exact bandwidth in Hz based on SCS and NRB
    % BW = NRB * 12 subcarriers * SCS
    currentSCS_Hz = scsList(fIdx) * 1e3;
    currentNRB = nrbList(fIdx);
    bw_hz = currentNRB * 12 * currentSCS_Hz;
    
    fprintf('  Bandwidth for %s: %.2f MHz\n', freqNames(fIdx), bw_hz/1e6);
    
    % Convert SNR from dB to Linear scale
    % SNR_linear = 10^(SNR_dB / 10)
    snrLinear = 10.^(squeeze(snrResults(fIdx, :, :)) ./ 10);
    
    % Shannon Capacity Formula: C = B * log2(1 + SNR)
    % maximizing for single stream (Upper Bound)
    capacity_bps = bw_hz .* log2(1 + snrLinear);
    
    % Convert to Gbps
    capacityResults(fIdx, :, :) = capacity_bps / 1e9;
end

% Plot Throughput
figure('Name', 'Throughput vs Distance', 'Position', [100 100 1000 400]);
t2 = tiledlayout(1,2);

% Subplot 1: BS1 Gachon (Throughput)
nexttile;
plot(dists, squeeze(capacityResults(1, 1, :)), '-o', 'LineWidth', 2, 'DisplayName', 'FR1 (100MHz)');
hold on;
plot(dists, squeeze(capacityResults(2, 1, :)), '-s', 'LineWidth', 2, 'DisplayName', 'FR2 (400MHz)');
grid on;
title('BS1 (Complex): Throughput');
xlabel('Distance (m)'); ylabel('Throughput (Gbps)');
legend('Location','best');

% Subplot 2: BS2 Seoul Airport (Throughput)
nexttile;
plot(dists, squeeze(capacityResults(1, 2, :)), '-o', 'LineWidth', 2, 'DisplayName', 'FR1 (100MHz)');
hold on;
plot(dists, squeeze(capacityResults(2, 2, :)), '-s', 'LineWidth', 2, 'DisplayName', 'FR2 (400MHz)');
grid on;
title('BS2 (Open): Throughput');
xlabel('Distance (m)'); ylabel('Throughput (Gbps)');
legend('Location','best');

sgtitle('Throughput Analysis: Bandwidth vs SNR Trade-off');

fprintf('Simulation Complete.\n');


%% Helper Function
function calculatedSNR = calculateLinkSNR(raysObj, fc, txPowerdBm, noiseFig, bsSize, ueSize, bsOri, ueOri, scs, nrb)
    
    if iscell(raysObj)
        if isempty(raysObj{1}), calculatedSNR = -Inf; return; end
        rays = raysObj{1};
    else
        rays = raysObj;
    end
    
    if isempty(rays), calculatedSNR = -Inf; return; end
    
    % [1] Find Best Path & Steering Angles
    [~, maxPathIdx] = min([rays.PathLoss]);
    targetRay = rays(maxPathIdx);
    steeringAz = targetRay.AngleOfDeparture(1);
    steeringEl = targetRay.AngleOfDeparture(2);
    
    % [2] Channel Params
    pathToAs = [rays.PropagationDelay] - min([rays.PropagationDelay]);
    avgPathGains = -[rays.PathLoss]; 
    pathAoDs = [rays.AngleOfDeparture];
    pathAoAs = [rays.AngleOfArrival];
    isLOS = any([rays.LineOfSight]);
    
    % [3] Configure Waveform
    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = scs;
    carrier.NSizeGrid = nrb;
    waveformInfo = nrOFDMInfo(carrier);
    
    % Generate signal
    txWaveform = ones(waveformInfo.SampleRate * 1e-3, 1); 
    txWaveform = txWaveform / sqrt(mean(abs(txWaveform).^2));
    
    % [4] Beamforming & Power
    c = physconst('LightSpeed');
    lambda = c/fc;
    
    bsArray = phased.NRRectangularPanelArray('Size',[bsSize(1:2) 1 1],'Spacing', [0.5*lambda*[1 1] 1 1]);
    bsArray.ElementSet = {phased.NRAntennaElement};
    ueArray = phased.NRRectangularPanelArray('Size',[ueSize(1:2) 1 1],'Spacing', [0.5*lambda*[1 1] 1 1]);
    ueArray.ElementSet = {phased.IsotropicAntennaElement};
    
    steerVec = phased.SteeringVector('SensorArray', bsArray);
    w = steerVec(fc, [steeringAz; steeringEl]); 
    w = w / norm(w); 
    
    txWaveform_Beamformed = txWaveform * w'; 
    txPowerWatts = 10^((txPowerdBm - 30) / 10);
    txWaveform_Final = txWaveform_Beamformed * sqrt(txPowerWatts);
    
    % [5] Channel
    channel = nrCDLChannel;
    channel.DelayProfile = 'Custom';
    channel.PathDelays = pathToAs;
    channel.AveragePathGains = avgPathGains;
    channel.AnglesAoD = pathAoDs(1,:); 
    channel.AnglesZoD = 90 - pathAoDs(2,:);
    channel.AnglesAoA = pathAoAs(1,:); 
    channel.AnglesZoA = 90 - pathAoAs(2,:);
    channel.HasLOSCluster = isLOS;
    channel.CarrierFrequency = fc;
    channel.NormalizeChannelOutputs = false; 
    channel.NormalizePathGains = false;      
    channel.TransmitAntennaArray = bsArray;
    channel.ReceiveAntennaArray = ueArray;
    channel.TransmitArrayOrientation = [bsOri(1); (-1)*bsOri(2); 0];
    channel.ReceiveArrayOrientation = [ueOri(1); (-1)*ueOri(2); 0];
    channel.SampleRate = waveformInfo.SampleRate;
    
    try
        [rxWaveform, ~] = channel(txWaveform_Final);
        
        rxPowerWatts = sum(mean(abs(rxWaveform).^2, 1));
        rxPowerdBm = 10*log10(rxPowerWatts) + 30;
        
        bw = nrb * 12 * scs * 1e3; 
        noisePowerdBm = -174 + 10*log10(bw) + noiseFig;
        
        calculatedSNR = rxPowerdBm - noisePowerdBm;
    catch
        calculatedSNR = -Inf;
    end
end