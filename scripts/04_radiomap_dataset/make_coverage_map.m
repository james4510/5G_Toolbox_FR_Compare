%% [Step 0] 초기 설정 (건물 맵 생성 때와 동일하게 유지)
clear; clc;

% 1. 맵 및 송신기 설정
osmFile = "_seongnam_map.osm";
if exist(osmFile, 'file')
    viewer = siteviewer("Basemap","openstreetmap","Buildings",osmFile);    
else
    viewer = siteviewer("Basemap", "openstreetmap");
end

bsPositions = [37.4516, 127.1295];
fc = 4.7e9;

tx = txsite("Name","Transmitter", ...
    "Latitude", bsPositions(1), ...
    "Longitude", bsPositions(2), ...
    "AntennaHeight", 10, ...
    "TransmitterPower", 46, ...
    "TransmitterFrequency", fc);

% 2. 레이 트레이싱 모델 설정
rtpm = propagationModel("raytracing", ...
    "Method", "sbr", ...
    "MaxNumReflections", 2, ...
    "MaxNumDiffractions", 1);
% rtpm.UseGPU = "on"; % GPU가 있다면 주석 해제 (더 빨라짐)

%% [Step 1] Coverage 실행 (시각화 데이터를 얻기 위함)
fprintf('커버리지 시뮬레이션 실행 중... (잠시만 기다려주세요)\n');

% Resolution: 낮을수록(숫자가 클수록) 빠르지만 거칠어짐. 2~3 정도 추천.
cov = coverage(tx, rtpm, ...
   "SignalStrengths", -120:-50, ...
   "MaxRange", 300, ... 
   "Resolution", 3); 

%% [Step 2] 데이터 추출 및 격자(Grid) 변환 (핵심 단계)
fprintf('데이터 추출 및 이미지 변환 중...\n');

% 1. Coverage 객체에서 데이터 꺼내기 (버전 호환성 처리)
if isprop(cov, 'Data') 
    % 최신 MATLAB (R2022b 이상)
    data = cov.Data;
    latData = data.Latitude;
    lonData = data.Longitude;
    powerData = data.Power; 
else
    % 구버전 MATLAB
    latData = cov.Latitude;
    lonData = cov.Longitude;
    powerData = cov.Power;
end

% 2. 딥러닝용 정사각 격자(Grid) 만들기 (256x256)
% (이전 건물 맵 코드와 동일한 좌표계 생성)
gridSize = 256;
mapWidthMeters = 500;

metersPerDegreeLat = 111000;
metersPerDegreeLon = 111000 * cosd(bsPositions(1));
deltaLat = (mapWidthMeters / 2) / metersPerDegreeLat;
deltaLon = (mapWidthMeters / 2) / metersPerDegreeLon;

latLim = [bsPositions(1) - deltaLat, bsPositions(1) + deltaLat];
lonLim = [bsPositions(2) - deltaLon, bsPositions(2) + deltaLon];

latVector = linspace(latLim(1), latLim(2), gridSize);
lonVector = linspace(lonLim(1), lonLim(2), gridSize);
[LON_GRID, LAT_GRID] = meshgrid(lonVector, latVector);

% 3. 흩어진 데이터를 격자 이미지로 변환 (Interpolation)
% scatteredInterpolant: 불규칙한 점 데이터를 규칙적인 격자로 채워줌
F = scatteredInterpolant(lonData, latData, powerData, 'linear', 'none');
powerMap = F(LON_GRID, LAT_GRID);

% 4. NaN(신호 없는 곳) 및 범위 처리
minSignal = -120;
powerMap(isnan(powerMap)) = minSignal; % 빈 곳은 최저값으로
powerMap(powerMap < minSignal) = minSignal; % 너무 낮은 값 클리핑

%% [Step 3] 결과 시각화 (논문 Figure 스타일)
figure('Color', 'w');

% imagesc로 그리기 (지도 배경 없이 데이터만)
imagesc(powerMap);

% 논문과 유사한 스타일 설정
colormap('parula'); % 또는 'jet'
clim([-120 -50]);   % 색상 범위 고정 (-120dBm ~ -50dBm)

% 축 및 여백 제거 (깔끔한 이미지)
axis xy;      % Y축 방향 (아래->위)
axis equal;   % 비율 유지
axis off;     % 눈금 제거
set(gca, 'Position', [0 0 1 1]); % 여백 없이 꽉 채우기

% 저장
save('coverage_map_fast.mat', 'powerMap');
exportgraphics(gca, 'coverage_only_clean.png', 'Resolution', 300);

fprintf('완료! \n 1. 이미지: coverage_only_clean.png \n 2. 데이터: coverage_map_fast.mat\n');