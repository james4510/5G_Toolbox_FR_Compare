%% =========================
%  Multi-UE CDL + Plots
% =========================
fc = 6e9;
bsPosition = [37.4535736, 127.1369074];
bsAntSize = [8 8];
bsArrayOrientation = [90 0].';

uePositions = [
    37.4555736 127.1329074;   % UE1
    37.4556736 127.1328074;   % UE2
    37.4557736 127.1330074;   % UE3
];
nUE = size(uePositions,1);

ueAntSize = [2 2];
ueArrayOrientation = [270 90].';
reflectionsOrder = 1;

SCS = 15;  % kHz
NRB = 52;  % ~10 MHz

% --- Site Viewer ---
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

bsSite = txsite("Name","Base station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2), ...
    "AntennaAngle",bsArrayOrientation(1:2), ...
    "AntennaHeight",4, ...
    "TransmitterFrequency",fc);

ueSites = repmat(rxsite,1,nUE);
for i = 1:nUE
    ueSites(i) = rxsite("Name",sprintf("UE%d",i), ...
        "Latitude",uePositions(i,1), ...
        "Longitude",uePositions(i,2), ...
        "AntennaHeight",1, ...
        "AntennaAngle",ueArrayOrientation(1:2));
end

show(bsSite);
show(ueSites);

% --- Ray tracing for all UEs ---
pm = propagationModel("raytracing","Method","sbr", ...
    "MaxNumReflections",reflectionsOrder,"MaxNumDiffractions",0);
raysAll = raytrace(bsSite, ueSites, pm, "Type","pathloss");

% --- Arrays & channel template ---
c = physconst('LightSpeed');
lambda = c/fc;

ueArray = phased.NRRectangularPanelArray('Size',[ueAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]);
ueArray.ElementSet = {phased.IsotropicAntennaElement};

bsArray = phased.NRRectangularPanelArray('Size',[bsAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement};

ofdmInfo = nrOFDMInfo(NRB,SCS);

channelTemplate = nrCDLChannel;
channelTemplate.DelayProfile = 'Custom';
channelTemplate.CarrierFrequency = fc;
channelTemplate.NormalizeChannelOutputs = false;
channelTemplate.NormalizePathGains  = false;
channelTemplate.ReceiveAntennaArray = ueArray;
channelTemplate.ReceiveArrayOrientation = [ueArrayOrientation(1); -ueArrayOrientation(2); 0];
channelTemplate.TransmitAntennaArray = bsArray;
channelTemplate.TransmitArrayOrientation = [bsArrayOrientation(1); -bsArrayOrientation(2); 0];
channelTemplate.SampleRate = ofdmInfo.SampleRate;
channelTemplate.ChannelFiltering = false;

% =========================
%  Per-UE channel & plots
% =========================
for i = 1:nUE
    if isempty(raysAll{i})
        fprintf("UE%d: no rays found\n", i);
        continue;
    end

    rays = raysAll{i};

    % --- Ray → CDL params ---
    pathToAs     = [rays.PropagationDelay] - min([rays.PropagationDelay]);
    avgPathGains = -[rays.PathLoss];               % dB
    pathAoDs     = [rays.AngleOfDeparture];
    pathAoAs     = [rays.AngleOfArrival];          % 오타 수정!
    isLOS        = any([rays.LineOfSight]);

    ch = clone(channelTemplate);
    ch.PathDelays       = pathToAs;
    ch.AveragePathGains = avgPathGains;
    ch.AnglesAoD        = pathAoDs(1,:);
    ch.AnglesZoD        = 90 - pathAoDs(2,:);
    ch.AnglesAoA        = pathAoAs(1,:);
    ch.AnglesZoA        = 90 - pathAoAs(2,:);
    ch.HasLOSCluster    = isLOS;

    % --- Channel response ---
    [pathGains, sampleTimes] = ch();               % 오타 수정!
    pg = permute(pathGains,[2 1 3 4]);             % 1st dim = #paths
    if isLOS && size(pg,1) >= 2
        pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)];% LOS 두 경로 합산
    end
    instPathG_dB = pow2db(abs(pg(:,1,1,1)).^2);

    % --- Perfect channel estimate ---
    pathFilters = getPathFilters(ch);
    nSlot = 0;
    [offset,~] = nrPerfectTimingEstimate(pathGains, pathFilters);
    hest = nrPerfectChannelEstimate(pathGains, pathFilters, NRB, SCS, nSlot, offset, sampleTimes);

    % --- Plot: Path Gains ---
    figure('Name',sprintf('UE%d Path Gains',i),'Color','w');
    hold on; grid on;
    plot(instPathG_dB,'o-','DisplayName','Instantaneous (1^{st} tx - 1^{st} rx)');
    plot(avgPathGains,'x--','DisplayName','Average (from ray tracing)');
    xlabel("Path number"); ylabel("Gain (dB)");
    title(sprintf("UE%d Path Gains", i));
    legend('Location','best'); hold off;

    % --- Plot: Channel Magnitude Response (1st tx - 1st rx) ---
    H2_dB = pow2db(abs(hest(:,:,1,1)).^2);
    figure('Name',sprintf('UE%d Channel Mag Resp',i),'Color','w');
    surf(H2_dB,'EdgeColor','none'); view(2);
    colormap(parula); colorbar;
    caxis([prctile(H2_dB(:),5), prctile(H2_dB(:),95)]);
    xlabel('OFDM Symbols'); ylabel('Subcarriers'); zlabel('Mag^2 (dB)');
    title(sprintf('UE%d Channel Magnitude Response (1^{st} tx - 1^{st} rx)', i));

    % --- (옵션) Beamforming weights + radiation pattern 원하면 아래 주석 해제 ---
    % nLayers = 1; scOffset = 0; noRBs = 1;
    % [wbs,wue,~] = getBeamformingWeights(hest,nLayers,scOffset,noRBs);
    % ueSites(i).Antenna = clone(ueArray); ueSites(i).Antenna.Taper = wue; pattern(ueSites(i), fc, "Size", 4);
    % bsSite.Antenna     = clone(bsArray); bsSite.Antenna.Taper     = wbs; pattern(bsSite,     fc, "Size", 5);
end

% =========================
%  로컬 함수 (파일 맨 아래)
% =========================
function [wtx,wrx,D] = getBeamformingWeights(hEst,nLayers,scOffset,noRBs)
    % Average channel over a narrow RB window
    [~,~,R,P] = size(hEst);
    scNo = scOffset + 1;
    hEstWin = hEst(scNo:scNo+(12*noRBs-1),:,:,:);
    H = permute(mean(reshape(hEstWin,[],R,P)),[2 3 1]);

    % SVD
    [U,D,V] = svd(H);
    wtx = V(:,1:nLayers).';
    wrx = U(:,1:nLayers)';
end