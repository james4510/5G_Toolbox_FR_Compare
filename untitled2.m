% gpu = gpuDevice;
% disp(gpu.Name + " GPU detected and available.")

osmFile = "_seongnam_map.osm";


if exist(osmFile, 'file')
    viewer = siteviewer("Basemap","openstreetmap","Buildings",osmFile);    
else
    viewer = siteviewer("Basemap", "openstreetmap");
end

bsPositions = [37.4516,127.1295];
bsAntennaHeight = 10;           % 안테나 높이 (m)
txPower = 46;                   % 송신 전력 (dBm)
fc = 4.7e9;              % 반송파 주파수 (Hz)

tx = txsite(Name="Transmitter", ...
    Latitude=bsPositions(1), ...
    Longitude=bsPositions(2), ...
    AntennaHeight=bsAntennaHeight, ...
    TransmitterPower=txPower, ...
    TransmitterFrequency=fc);
show(tx)

fprintf('\n레이 트레이싱 모델 설정\n');

maxReflections = 2;
maxDiffractions = 1;

% https://kr.mathworks.com/help/comm/ref/propagationmodel.html
rtpm = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=maxReflections, ...
    MaxNumDiffractions=maxDiffractions);

% GPU 없는 경우 주석 처리
% rtpm.UseGPU="on";

%% [기존 코드 유지] 초기 설정 및 모델링
% ... (osmFile, bsPositions, tx, rtpm 설정까지는 동일) ...

%% [수정된 부분] 논문 스타일의 히트맵 생성 및 시각화

% 1. 시각화할 영역의 해상도와 범위 설정
gridSize = 256;         % 논문과 유사한 해상도 (예: 256x256)
mapWidthMeters = 500;   % 커버리지 범위 (지름 500m)

% 2. 격자(Meshgrid) 좌표 생성
% 송신기(Tx)를 중심으로 사각형 그리드를 만듭니다.
metersPerDegreeLat = 111000;
metersPerDegreeLon = 111000 * cosd(bsPositions(1));
deltaLat = (mapWidthMeters / 2) / metersPerDegreeLat;
deltaLon = (mapWidthMeters / 2) / metersPerDegreeLon;

latVector = linspace(bsPositions(1) - deltaLat, bsPositions(1) + deltaLat, gridSize);
lonVector = linspace(bsPositions(2) - deltaLon, bsPositions(2) + deltaLon, gridSize);
[LON_GRID, LAT_GRID] = meshgrid(lonVector, latVector);

% 3. 신호 세기(RSRP) 계산 (sigstrength 사용)
fprintf('신호 세기 계산 중... (Grid: %dx%d)\n', gridSize, gridSize);
rxGrid = rxsite("Latitude", LAT_GRID(:), ...
                "Longitude", LON_GRID(:), ...
                "AntennaHeight", 1.5); % 수신 높이 1.5m 가정

ss = sigstrength(rxGrid, tx, rtpm); % 계산 수행

% 4. 데이터 행렬 변환 및 전처리
powerMap = reshape(ss, gridSize, gridSize);

% 수신 불가 지역(NaN)을 최저값(예: -120dBm)으로 채움 (논문의 파란색 배경)
minSignal = -120;
powerMap(isnan(powerMap)) = minSignal;

%% [결과 시각화] Figure 2(d) 스타일
figure('Color', 'w'); % 배경 흰색

% imagesc: 행렬 데이터를 이미지처럼 출력하는 함수
imagesc(powerMap);

% 논문과 유사한 컬러맵 설정 (Parula 또는 Jet 추천)
% MATLAB 기본값인 'parula'가 논문 이미지와 가장 유사합니다.
colormap('parula'); 
% colormap('jet'); % 만약 빨강-파랑 대비가 더 강해야 한다면 jet 사용

% 컬러바 범위 고정 (논문의 색상 스케일과 맞추기 위해 중요)
clim([-120 -50]); 
% colorbar; % 필요하면 주석 해제하여 범례 확인

% 축 및 여백 제거 (Clean Image)
axis xy;      % Y축 방향을 지도 좌표계에 맞게(아래->위) 설정
axis equal;   % 가로세로 비율 유지
axis off;     % X, Y축 눈금 및 테두리 제거 (가장 중요)
set(gca, 'Position', [0 0 1 1]); % 여백 없이 꽉 채우기

title(''); % 제목 제거