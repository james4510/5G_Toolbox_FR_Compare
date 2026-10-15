%% 1. 환경 설정 및 맵 로드
clear; clc; close all;
viewer = siteviewer(Buildings="seongnam_map.osm", Basemap="topographic");

%% 2. 송신국 (Transmitter) 설정 - 가천대 AI 공학관 위치
% 논문 비교를 위해 동일 위치 고정
tx_lat = 37.455715;
tx_lon = 127.133562;
tx_h   = 30; % 건물 옥상 등을 고려하여 30m로 가정 (필요시 수정)

tx = txsite(Name="Base Station", ...
    Latitude=tx_lat, ...
    Longitude=tx_lon, ...
    AntennaHeight=tx_h, ...
    TransmitterPower=40); % 40W (일반적인 Macro/Micro 기지국 출력)

show(tx);

%% 3. 수신국 (UE) 샘플링 설정 (데이터 추출용)
% 송신국 주변 300m 반경 내에 무작위로 50개의 수신기 배치
num_rx = 50; 
max_dist = 300; % 미터 단위

% 거리와 각도를 무작위 생성하여 좌표 계산 (약식 계산)
rng(42); % 결과 재현을 위한 시드 고정
dists = max_dist * sqrt(rand(1, num_rx)); % 균등 분포를 위한 제곱근
angles = 2 * pi * rand(1, num_rx);

% 위도(Lat), 경도(Lon) 변환 (1 deg approx 111km)
rx_lats = tx_lat + (dists .* cos(angles)) / 111000;
rx_lons = tx_lon + (dists .* sin(angles)) / (111000 * cosd(tx_lat));

% 수신기 배열 생성
rxs = rxsite(Name="UE", ...
    Latitude=rx_lats, ...
    Longitude=rx_lons, ...
    AntennaHeight=1.5); % 보행자 높이

show(rxs);

%% 4. 시뮬레이션 실행: Scenario 1 vs Scenario 2

% --- [Scenario 1: 4.7 GHz (FR1 - 5G 특화망)] ---
% 특징: 회절(Diffraction)이 잘 일어남 -> NLoS 커버리지 우수
tx.TransmitterFrequency = 4.7e9;
pm_fr1 = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=2, ...
    MaxNumDiffractions=1, ... % [중요] FR1은 회절 1회 허용
    BuildingsMaterial="concrete", ...
    TerrainMaterial="concrete");

fprintf('Simulating FR1 (4.7 GHz)...\n');
rays_fr1 = raytrace(tx, rxs, pm_fr1);

% --- [Scenario 2: 28 GHz (FR2 - mmWave)] ---
% 특징: 직진성 강함, 회절 거의 없음 -> NLoS에서 급격한 감쇄
tx.TransmitterFrequency = 28e9;
pm_fr2 = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=3, ... % 반사는 더 많이 고려
    MaxNumDiffractions=0, ... % [중요] FR2는 회절 무시 (혹은 매우 약함)
    BuildingsMaterial="concrete", ...
    TerrainMaterial="concrete");

fprintf('Simulating FR2 (28 GHz)...\n');
rays_fr2 = raytrace(tx, rxs, pm_fr2);

%% 5. 데이터 추출 (거리 vs 수신전력)

% 데이터 저장용 배열
data_fr1 = zeros(num_rx, 2); % [거리, 파워]
data_fr2 = zeros(num_rx, 2);

for i = 1:num_rx
    % 거리 계산 (송신국 - 수신국)
    d = distance(tx, rxs(i));
    
    % FR1 수신 전력 계산 (경로가 없으면 -200 dBm 처리)
    if ~isempty(rays_fr1{i})
        p_watts = sum([rays_fr1{i}.ReceivedPower]); % 다중경로 합산
        p_dbm_fr1 = 10*log10(p_watts) + 30;
    else
        p_dbm_fr1 = -200; % Outage
    end
    
    % FR2 수신 전력 계산
    if ~isempty(rays_fr2{i})
        p_watts = sum([rays_fr2{i}.ReceivedPower]);
        p_dbm_fr2 = 10*log10(p_watts) + 30;
    else
        p_dbm_fr2 = -200;
    end
    
    data_fr1(i,:) = [d, p_dbm_fr1];
    data_fr2(i,:) = [d, p_dbm_fr2];
end

%% 6. 결과 그래프 그리기 (논문용)
figure('Name', 'Path Loss Comparison', 'Color', 'w');
hold on; grid on;

% FR1 (4.7 GHz) 데이터 플롯
scatter(data_fr1(:,1), data_fr1(:,2), 70, 'b', 'filled', 'DisplayName', 'FR1 (4.7 GHz)');
% FR2 (28 GHz) 데이터 플롯
scatter(data_fr2(:,1), data_fr2(:,2), 70, 'r', 'filled', 'DisplayName', 'FR2 (28 GHz)');

% 그래프 꾸미기
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Received Power (dBm)', 'FontSize', 12, 'FontWeight', 'bold');
title('Coverage Analysis: 4.7 GHz vs 28 GHz in Urban Campus', 'FontSize', 14);
legend('Location', 'best');
ylim([-140 -40]); % Y축 범위 설정 (Outage 제외하고 보기 위함)

% [분석 포인트] 수신 감도 임계값 라인 (예: -100 dBm)
yline(-100, '--k', 'Cell Edge Coverage Threshold (-100 dBm)', 'LineWidth', 1.5);

hold off;