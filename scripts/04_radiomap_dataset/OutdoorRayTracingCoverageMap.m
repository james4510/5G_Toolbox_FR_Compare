clear; clc;

% 1. 맵 및 송신기 설정
osmFile = "seongnam_map.osm";
if exist(osmFile, 'file')
    viewer = siteviewer("Basemap","openstreetmap","Buildings",osmFile);    
else
    viewer = siteviewer("Basemap", "openstreetmap");
end

bsPositions = [37.4516, 127.1295];
bsAntennaHeight = 10;
txPower = 46;
fc = 4.7e9;

tx = txsite("Name","Transmitter", ...
    "Latitude", bsPositions(1), ...
    "Longitude", bsPositions(2), ...
    "AntennaHeight", bsAntennaHeight, ...
    "TransmitterPower", txPower, ...
    "TransmitterFrequency", fc);

% 2. 레이 트레이싱 모델 설정
maxReflections = 2; 
maxDiffractions = 1;

rtpm = propagationModel("raytracing", ...
    "Method", "sbr", ...
    "MaxNumReflections", maxReflections, ...
    "MaxNumDiffractions", maxDiffractions);

% rtpm.UseGPU = "on"; GPU % 사용여부

%% [격자 생성]
gridSize = 256;         
mapWidthMeters = 500;   

metersPerDegreeLat = 111000;
metersPerDegreeLon = 111000 * cosd(bsPositions(1));
deltaLat = (mapWidthMeters / 2) / metersPerDegreeLat;
deltaLon = (mapWidthMeters / 2) / metersPerDegreeLon;

latVector = linspace(bsPositions(1) - deltaLat, bsPositions(1) + deltaLat, gridSize);
lonVector = linspace(bsPositions(2) - deltaLon, bsPositions(2) + deltaLon, gridSize);
[LON_GRID, LAT_GRID] = meshgrid(lonVector, latVector);

%% 신호 세기 분할 계산 (Batch Processing)
fprintf('신호 세기 계산 시작 (총 %d 개 지점)\n', numel(LAT_GRID));

% 전체 데이터를 1차원 벡터로 변환
latAll = LAT_GRID(:);
lonAll = LON_GRID(:);
totalPoints = numel(latAll);
ssAll = zeros(totalPoints, 1); % 결과 저장할 배열

% 한 번에 계산할 크기
batchSize = 1000; 
numBatches = ceil(totalPoints / batchSize);

% 진행률바 생성
h = waitbar(0, '레이 트레이싱 계산 중...');

tStart = tic; % 시간 측정 시작

for i = 1:numBatches
    % 현재 배치의 시작과 끝 인덱스 계산
    idxStart = (i-1)*batchSize + 1;
    idxEnd = min(i*batchSize, totalPoints);
    
    % 임시 수신기 생성 (이 배치만큼만)
    rxSub = rxsite("Latitude", latAll(idxStart:idxEnd), ...
                   "Longitude", lonAll(idxStart:idxEnd), ...
                   "AntennaHeight", 1.5);
    
    % 신호 세기 계산
    ssAll(idxStart:idxEnd) = sigstrength(rxSub, tx, rtpm);
    
    % 진행 상황 업데이트 (명령창 및 진행률바)
    progress = i / numBatches;
    elapsedTime = toc(tStart);
    estimatedTotalTime = elapsedTime / progress;
    remainingTime = estimatedTotalTime - elapsedTime;
    
    % 10% 단위로 로그 출력
    if mod(i, 10) == 0 || i == numBatches
        fprintf('진행률: %.1f%% (%d/%d 배치) - 남은 시간: 약 %.0f초\n', ...
            progress*100, i, numBatches, remainingTime);
    end
    waitbar(progress, h, sprintf('계산 중... %.1f%% 완료 (남은 시간: 약 %.0f초)', progress*100, remainingTime));
end
close(h);
fprintf('계산 완료!\n');

%% [시각화 및 저장]
% 1. 데이터 행렬 변환
powerMap = reshape(ssAll, gridSize, gridSize);

% 2. NaN 처리 (수신 불가 지역)
minSignal = -120;
powerMap(isnan(powerMap)) = minSignal;

% 3. 시각화
figure('Color', 'w');
imagesc(powerMap);
colormap('parula'); 
clim([-120 -50]); 
axis xy; axis equal; axis off;
set(gca, 'Position', [0 0 1 1]);

% 4. 저장
save('result_matrix.mat', 'powerMap');