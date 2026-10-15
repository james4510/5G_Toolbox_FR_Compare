%% === Site Viewer 생성 및 BS/UE 배치 ===
fc = 6e9;
bsPosition = [37.4535736, 127.1369074];
uePosition = [37.4555736, 127.1329074];
bsArrayOrientation = [-180 0].';
ueArrayOrientation = [270 90].';

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

ueSite = rxsite("Name","UE", ...
    "Latitude",uePosition(1),"Longitude",uePosition(2), ...
    "AntennaHeight",1, ...
    "AntennaAngle",ueArrayOrientation(1:2));

show(bsSite);
show(ueSite);

%% === 레이 트레이싱 및 표시(단일 UE) ===
pm = propagationModel("raytracing","Method","sbr","MaxNumReflections",1,"MaxNumDiffractions",0);
rays = raytrace(bsSite, ueSite, pm, "Type","pathloss");
if ~isempty(rays) && ~isempty(rays{1})
    plot(rays{1});
end

%% === 안테나 패턴 표시(가중치가 있으면 적용) ===
c = physconst('LightSpeed'); lambda = c/fc;

ueArray = phased.NRRectangularPanelArray('Size',[2 2 1 1], 'Spacing',[0.5*lambda*[1 1] 1 1]);
ueArray.ElementSet = {phased.IsotropicAntennaElement};
ueAnt = clone(ueArray);
if exist('wue','var') && ~isempty(wue), ueAnt.Taper = wue; end
ueSite.Antenna = ueAnt;
pattern(ueSite, fc, "Size", 4);

bsArray = phased.NRRectangularPanelArray('Size',[8 8 1 1], 'Spacing',[0.5*lambda*[1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement};
bsAnt = clone(bsArray);
if exist('wbs','var') && ~isempty(wbs), bsAnt.Taper = wbs; end
bsSite.Antenna = bsAnt;
pattern(bsSite, fc, "Size", 5);

%% === 여러 UE 배치 및 레이 오버레이 ===
uePositions = [
    37.4547 127.1343
    37.4544 127.1339
    37.4541 127.1342
    37.4546 127.1345
    37.4547 127.1336
    37.4542 127.1341
];
nUE = size(uePositions,1);

ueSites = repmat(rxsite,1,nUE);
for i = 1:nUE
    ueSites(i) = rxsite("Name",sprintf("UE%d",i), ...
        "Latitude",uePositions(i,1),"Longitude",uePositions(i,2), ...
        "AntennaHeight",1, ...
        "AntennaAngle",ueArrayOrientation(1:2));
end
show(ueSites);

raysAll = raytrace(bsSite, ueSites, pm, "Type","pathloss");

colors = lines(numel(ueSites));
ax = gca;
for i = 1:numel(ueSites)
    if isempty(raysAll{i}), continue; end
    co = ax.ColorOrder;
    ax.ColorOrder = colors(i,:);
    for k = 1:numel(raysAll{i})
        plot(raysAll{i}(k));
        hold on;
    end
    ax.ColorOrder = co;
end
title('Rays from one BS to multiple UEs (LOS & reflections)');
hold off;

%% === 여러 UE 방사 패턴 플로팅 (UE별 수신 빔 조향) ===
% 준비: UE 배열 정의 (위에서 만든 ueArray 재사용)
c = physconst('LightSpeed');
svUE = phased.SteeringVector('SensorArray', ueArray, ...
    'PropagationSpeed', c);

for i = 1:nUE
    if isempty(raysAll{i})
        fprintf('[UE%d] No rays. Skip UE pattern.\n', i);
        continue;
    end

    % 지배 경로(가장 낮은 PathLoss) 선택
    [~, idxBest] = min([raysAll{i}.PathLoss]);

    % UE 기준 입사각 (Az, El) [deg]
    aoa = raysAll{i}(idxBest).AngleOfArrival; % 2x1 [az; el], deg

    % 스티어링 벡터 (수신 빔) 계산
    wue_i = svUE(fc, aoa);          % column vector
    wue_i = wue_i(:).' ./ max(abs(wue_i));  % 정규화 및 row vector

    % 해당 UE 안테나에 가중치 적용 후 패턴 표시
    ueAnt_i = clone(ueArray);
    ueAnt_i.Taper = wue_i;
    ueSites(i).Antenna = ueAnt_i;
    pattern(ueSites(i), fc, "Size", 4);
    title(sprintf("UE%d Radiation Pattern (steered to AoA: az=%.1f°, el=%.1f°)", ...
        i, aoa(1), aoa(2)));
end

%% === (옵션) BS 방사 패턴도 UE별로 플로팅 (BS 송신 빔 조향) ===
% 주의: BS는 마지막에 설정된 빔이 유지됩니다. 각 UE마다 오버레이로 표시됩니다.
svBS = phased.SteeringVector('SensorArray', bsArray, ...
    'PropagationSpeed', c);

for i = 1:nUE
    if isempty(raysAll{i})
        fprintf('[UE%d] No rays. Skip BS pattern for this UE.\n', i);
        continue;
    end

    % 지배 경로(가장 낮은 PathLoss) 선택
    [~, idxBest] = min([raysAll{i}.PathLoss]);

    % BS 기준 출사각 (Az, El) [deg]
    aod = raysAll{i}(idxBest).AngleOfDeparture; % 2x1 [az; el], deg

    % 스티어링 벡터 (송신 빔) 계산
    wbs_i = svBS(fc, aod);           % column vector
    wbs_i = wbs_i(:).' ./ max(abs(wbs_i));

    % BS 안테나에 가중치 적용 후 패턴 표시
    bsAnt_i = clone(bsArray);
    bsAnt_i.Taper = wbs_i;
    bsSite.Antenna = bsAnt_i;
    pattern(bsSite, fc, "Size", 5);
    title(sprintf("BS Radiation Pattern toward UE%d (AoD: az=%.1f°, el=%.1f°)", ...
        i, aod(1), aod(2)));
end

%% === 각 UE: Path Gain / Channel Magnitude Response 플롯 ===
% NRB, SCS가 없으면 기본값 설정
if ~exist('NRB','var') || isempty(NRB), NRB = 52; end     % ~10 MHz
if ~exist('SCS','var') || isempty(SCS), SCS = 15; end     % kHz

% 공통 채널 템플릿
ofdmInfo = nrOFDMInfo(NRB, SCS);

channelTemplate = nrCDLChannel;
channelTemplate.DelayProfile = 'Custom';
channelTemplate.CarrierFrequency = fc;
channelTemplate.NormalizeChannelOutputs = false;
channelTemplate.NormalizePathGains  = false;
channelTemplate.ReceiveAntennaArray = ueArray;
channelTemplate.ReceiveArrayOrientation = [ueArrayOrientation(1); (-1)*ueArrayOrientation(2); 0];
channelTemplate.TransmitAntennaArray = bsArray;
channelTemplate.TransmitArrayOrientation = [bsArrayOrientation(1); (-1)*bsArrayOrientation(2); 0];
channelTemplate.SampleRate = ofdmInfo.SampleRate;
channelTemplate.ChannelFiltering = false;

for i = 1:nUE
    if isempty(raysAll{i})
        fprintf('[UE%d] No rays -> skip path/channel plots.\n', i);
        continue;
    end

    rays_i = raysAll{i};

    % === Ray Tracing -> CDL 파라미터 매핑 ===
    pathToAs      = [rays_i.PropagationDelay] - min([rays_i.PropagationDelay]);
    avgPathGains  = -[rays_i.PathLoss];          % dB
    pathAoDs      = [rays_i.AngleOfDeparture];
    pathAoAs      = [rays_i.AngleOfArrival];
    isLOS_i       = any([rays_i.LineOfSight]);

    ch = clone(channelTemplate);
    ch.PathDelays       = pathToAs;
    ch.AveragePathGains = avgPathGains;
    ch.AnglesAoD        = pathAoDs(1,:);
    ch.AnglesZoD        = 90 - pathAoDs(2,:);
    ch.AnglesAoA        = pathAoAs(1,:);
    ch.AnglesZoA        = 90 - pathAoAs(2,:);
    ch.HasLOSCluster    = isLOS_i;

    % === 채널 응답 생성 & 완전 채널추정 ===
    [pathGains, sampleTimes] = ch();
    pathFilters = getPathFilters(ch);
    nSlot = 0;
    [offset, ~] = nrPerfectTimingEstimate(pathGains, pathFilters);
    hest = nrPerfectChannelEstimate(pathGains, pathFilters, NRB, SCS, nSlot, offset, sampleTimes);

    % === Path Gains (즉시/평균) ===
    pg = permute(pathGains,[2 1 3 4]);   % 1차원: path
    if isLOS_i && size(pg,1) >= 2
        % LOS 두 경로(직접+CP 길이상 분리되는 첫 경로) 합침
        pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)];
    end
    pg = abs(pg).^2;
    instPathG_dB = pow2db(pg(:,1,1,1));  % 1st tx - 1st rx

    % === 채널 크기 응답(1st tx - 1st rx) ===
    H2_dB = pow2db(abs(hest(:,:,1,1)).^2);

    % === 플롯 ===
    figure('Name',sprintf('UE%d Path/Channel',i),'Color','w');
    t = tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

    % (1) Path Gains
    ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on');
    plot(ax1, instPathG_dB, 'o-','DisplayName','Instantaneous (1st tx - 1st rx)');
    plot(ax1, avgPathGains, 'x--','DisplayName','Average (from ray tracing)');
    xlabel(ax1,"Path number"); ylabel(ax1,"Gain (dB)");
    title(ax1, sprintf("UE%d Path Gains", i));
    legend(ax1,'Location','best'); hold(ax1,'off');

    % (2) Channel Magnitude Response
    ax2 = nexttile;
    surf(ax2, H2_dB, 'EdgeColor','none'); view(ax2,2);
    colormap(ax2, parula); colorbar(ax2);
    caxis(ax2, [prctile(H2_dB(:),5) prctile(H2_dB(:),95)]);
    xlabel(ax2,'OFDM Symbols'); ylabel(ax2,'Subcarriers');
    title(ax2, sprintf("UE%d Channel Mag. Resp. (1st tx - 1st rx)", i));
end