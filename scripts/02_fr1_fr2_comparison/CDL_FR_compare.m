fc = 4.7e9;
% 기지국 구성
bsPosition = [37.4558, 127.1333]; % lat, lon (기지국)
bsAntSize = [8 8];
bsArrayOrientation = [90 0].';

% 대표 포인트 6개 (상세 분석용)
uePoints = [
    37.4554 127.1334; % point 1
];

% UE 안테나 파라미터
ueAntSize = [2 2];
ueArrayOrientation = [-30 45].';

% 반사 개수
reflectionsOrder = 1;

% OFDM 설정
SCS = 15;
NRB = 52;

% Siteviewer 실행
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

% 기지국 Site 생성
bsSite = txsite("Name", "Base station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2), ...
    "AntennaAngle",bsArrayOrientation(1:2), ...
    "AntennaHeight", 8, ...
    "TransmitterFrequency", fc);

% UE Site 생성
ueSites = rxsite.empty(size(uePoints,1),0);
for idx = 1:size(uePoints,1)
    ueSites(idx) = rxsite("Name",sprintf("UE %d",idx), ...
        "Latitude", uePoints(idx, 1), ...
        "Longitude", uePoints(idx, 2), ...
        "AntennaHeight", 1, ...
        "AntennaAngle", ueArrayOrientation(1:2));
end

% 기지국, UE 위치 시각화
show(bsSite);
show(ueSites);

% 레이 트레이싱 분석
pm = propagationModel("raytracing", "Method", "sbr", ...
    "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
rays = raytrace(bsSite,ueSites,pm,"Type","pathloss");

% 사이트 뷰어에 모든 UE에 대한 레이 표시
for idx = 1:length(rays)
    plot(rays{idx});
end

% 모든 UE에 대한 레이 트레이싱 파라미터 추출
numUEs = length(rays);

% 각 UE별 파라미터를 저장할 cell array 초기화
PathToAs = cell(numUEs, 1);
avgPathGains = cell(numUEs, 1);
pathAoDs = cell(numUEs, 1);
pathAoAs = cell(numUEs, 1);
isLOS = false(numUEs, 1);

% 각 UE에 대해 파라미터 추출
for idx = 1:numUEs
    % 도래 시간 - 최소값 기준으로 정규화
    PathToAs{idx} = [rays{idx}.PropagationDelay] - min([rays{idx}.PropagationDelay]);
    avgPathGains{idx} = -[rays{idx}.PathLoss];
    pathAoDs{idx} = [rays{idx}.AngleOfDeparture];
    pathAoAs{idx} = [rays{idx}.AngleOfArrival];
    isLOS(idx) = any([rays{idx}.LineOfSight]);
end

%% 채널 모델 생성 및 분석 (각 UE별로)

% 공통 파라미터 계산
c = physconst('LightSpeed');
lambda = c/fc;
ofdmInfo = nrOFDMInfo(NRB,SCS);

% UE 안테나 어레이 생성 (공통)
ueArray = phased.NRRectangularPanelArray('Size',[ueAntSize(1:2) 1 1],...
    'Spacing', [0.5*lambda*[1 1] 1 1]);
ueArray.ElementSet = {phased.IsotropicAntennaElement};

% 기지국 안테나 어레이 생성 (공통)
bsArray = phased.NRRectangularPanelArray('Size',[bsAntSize(1:2) 1 1],...
    'Spacing', [0.5*lambda*[1 1] 1 1]);
bsArray.ElementSet = {phased.NRAntennaElement};

% 각 UE별 채널 생성 및 분석
channels = cell(numUEs, 1);
pathGainsAll = cell(numUEs, 1);
sampleTimesAll = cell(numUEs, 1);
hestAll = cell(numUEs, 1);
wbsAll = cell(numUEs, 1);
wueAll = cell(numUEs, 1);

for ueIdx = 1:numUEs
    fprintf('Processing UE %d...\n', ueIdx);
    
    % 각 UE에 대한 CDL 채널 생성
    channel = nrCDLChannel;
    channel.DelayProfile = 'Custom';
    channel.PathDelays = PathToAs{ueIdx};
    channel.AveragePathGains = avgPathGains{ueIdx};
    channel.AnglesAoD = pathAoDs{ueIdx}(1,:);       % azimuth of departure
    channel.AnglesZoD = 90-pathAoDs{ueIdx}(2,:);    % zenith angle
    channel.AnglesAoA = pathAoAs{ueIdx}(1,:);       % azimuth of arrival
    channel.AnglesZoA = 90-pathAoAs{ueIdx}(2,:);    % zenith angle
    channel.HasLOSCluster = isLOS(ueIdx);
    channel.CarrierFrequency = fc;
    channel.NormalizeChannelOutputs = false;
    channel.NormalizePathGains = false;
    
    % 안테나 어레이 설정
    channel.ReceiveAntennaArray = ueArray;
    channel.ReceiveArrayOrientation = [ueArrayOrientation(1); (-1)*ueArrayOrientation(2); 0];
    channel.TransmitAntennaArray = bsArray;
    channel.TransmitArrayOrientation = [bsArrayOrientation(1); (-1)*bsArrayOrientation(2); 0];
    
    % 샘플링 레이트 설정
    channel.SampleRate = ofdmInfo.SampleRate;
    
    % 채널 필터링 비활성화 및 경로 이득 획득
    channel.ChannelFiltering = false;
    [pathGains, sampleTimes] = channel();
    
    % 채널 저장
    channels{ueIdx} = channel;
    pathGainsAll{ueIdx} = pathGains;
    sampleTimesAll{ueIdx} = sampleTimes;
    
    % 경로 이득 처리 (LOS의 경우 첫 두 경로 합산)
    pg = permute(pathGains,[2 1 3 4]);
    if isLOS(ueIdx)
        pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)];
    end
    pg = abs(pg).^2;
    
    % 경로 이득 플롯 (각 UE별)
    figure('Name', sprintf('UE %d - Path Gains', ueIdx));
    plot(pow2db(pg(:,1,1,1)),'o-.','LineWidth',1.5,'DisplayName','Instantaneous');
    hold on;
    plot(avgPathGains{ueIdx},'x-.','LineWidth',1.5,'DisplayName','Average (Ray Tracing)');
    hold off;
    legend('Location','best');
    xlabel('Path number');
    ylabel('Gain (dB)');
    title(sprintf('UE %d - Path Gains Comparison', ueIdx));
    grid on;
    
    % 채널 추정
    pathFilters = getPathFilters(channel);
    nSlot = 0;
    [offset,~] = nrPerfectTimingEstimate(pathGains, pathFilters);
    hest = nrPerfectChannelEstimate(pathGains, pathFilters, NRB, SCS, nSlot, offset, sampleTimes);
    hestAll{ueIdx} = hest;
    
    % 채널 주파수 응답 플롯
    figure('Name', sprintf('UE %d - Channel Response', ueIdx));
    surf(pow2db(abs(hest(:,:,1,1)).^2));
    shading('flat');
    xlabel('OFDM Symbols');
    ylabel('Subcarriers');
    zlabel('Magnitude Squared (dB)');
    title(sprintf('UE %d - Channel Magnitude Response (1st Tx - 1st Rx)', ueIdx));
    colorbar;
    
    % 빔포밍 가중치 계산
    nLayers = 1;
    scOffset = 0;
    noRBs = 1;
    [wbs, wue, ~] = getBeamformingWeights(hest, nLayers, scOffset, noRBs);
    wbsAll{ueIdx} = wbs;
    wueAll{ueIdx} = wue;
    
    fprintf('UE %d processing completed.\n\n', ueIdx);
end

%% 빔포밍 패턴 시각화 (선택적으로 특정 UE에 대해)
% 예: 첫 번째 UE의 빔포밍 패턴 표시
selectedUE = 1;

% UE 안테나 패턴
ueSites(selectedUE).Antenna = clone(ueArray);
ueSites(selectedUE).Antenna.Taper = wueAll{selectedUE};
pattern(ueSites(selectedUE), fc, "Size", 4);

% 기지국 안테나 패턴
bsSite.Antenna = clone(bsArray);
bsSite.Antenna.Taper = wbsAll{selectedUE};
pattern(bsSite, fc, "Size", 5);

%% 전체 UE에 대한 요약 통계
fprintf('\n===== Multi-UE Ray Tracing Summary =====\n');
for ueIdx = 1:numUEs
    fprintf('UE %d:\n', ueIdx);
    fprintf('  Position: (%.5f, %.5f)\n', uePoints(ueIdx,1), uePoints(ueIdx,2));
    fprintf('  Number of paths: %d\n', length(PathToAs{ueIdx}));
    fprintf('  LOS condition: %s\n', string(isLOS(ueIdx)));
    fprintf('  Max path gain: %.2f dB\n', max(avgPathGains{ueIdx}));
    fprintf('  Min path gain: %.2f dB\n', min(avgPathGains{ueIdx}));
    fprintf('  Path delay spread: %.2f ns\n', max(PathToAs{ueIdx})*1e9);
    fprintf('\n');
end

%% 빔포밍 가중치 함수
function [wtx, wrx, D] = getBeamformingWeights(hEst, nLayers, scOffset, noRBs)
% Get beamforming weights given a channel matrix hEst and the number of
% layers nLayers. One set of weights is provided for the whole bandwidth.
% The beamforming weights are calculated using singular value (SVD)
% decomposition.

    % Average channel estimate
    [~,~,R,P] = size(hEst);
    scNo = scOffset+1;
    hEst = hEst(scNo:scNo+(12*noRBs-1),:,:,:);
    H = permute(mean(reshape(hEst,[],R,P)),[2 3 1]);
    
    % SVD decomposition
    [U,D,V] = svd(H);
    wtx = V(:,1:nLayers).';
    wrx = U(:,1:nLayers)';
end