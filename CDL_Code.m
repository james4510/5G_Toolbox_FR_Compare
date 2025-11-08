%% 0. 환경 설정 및 변수 정의 (기존 코드 요소 활용)
% --- 귀하의 기존 코드 설정 ---
fc = 28e9; % carrier frequency (Hz)
bsPosition = [37.4536, 127.1369]; % lat, lon (단일 BS 기준 위치 - 영역 중앙 정의에 사용)
bsAntSize = [8 8]; % number of rows and columns in rectangular array (base station)
bsArrayOrientation = [180 0].'; % azimuth (0 deg is East, 90 deg is North) and elevation (positive points upwards) in deg
reflectionsOrder = 3; % Ray Tracing에 필요한 반사 횟수

% --- 네트워크 가용성 분석을 위한 추가 설정 ---
P_req = -95; % dBm: 최소 수신 감도 (네트워크 가용성 판단 기준)
tx_power_dbm = 30; % dBm: 송신 전력 (1W = 30 dBm)
tx_height = 4; % m: 기지국 안테나 높이 
rx_height = 1.5; % m: 수신기 안테나 높이 

% 시뮬레이션 영역 정의 (약 600m x 600m 영역)
lat_center = bsPosition(1);
lon_center = bsPosition(2);
area_extent_deg = 0.003; % 위도/경도 ±0.003도 범위 (약 300m 범위)

% 격자 해상도 설정 
grid_spacing_deg = 0.000015; % 1.7m에 해당하는 위경도 차이

lat_coords = (lat_center - area_extent_deg) : grid_spacing_deg : (lat_center + area_extent_deg);
lon_coords = (lon_center - area_extent_deg) : grid_spacing_deg : (lon_center + area_extent_deg);
[LON, LAT] = meshgrid(lon_coords, lat_coords);

% 전체 격자점 개수
total_points = numel(LON);

% Ray Tracing 전파 모델 설정
pm = propagationModel("raytracing","Method","sbr","MaxNumReflections",reflectionsOrder,"MaxNumDiffractions",0);

% --- 가용성 계산을 위한 수신기 배열 생성 ---
rx_positions_lat = LAT(:);
rx_positions_lon = LON(:);
rxs = rxsite("Name","Grid UE", ...
    "Latitude",rx_positions_lat, "Longitude",rx_positions_lon,...
    "AntennaHeight",rx_height);

% --- 핵심 변수: BS 간격 배열 및 변환 상수 ---
bs_separation_m = [50, 40, 30, 20, 10]; % BS 간격 후보 (m)
availability_results = zeros(size(bs_separation_m)); % 결과를 저장할 배열

% 성남 위도(37.45도)에서의 근사 변환 계수
lat_per_m = 0.000008983; 
lon_per_m = 0.000011158 / cosd(lat_center); % 위도 보정

%% 1. 시뮬레이션 환경 설정 및 루프 시작 (기존 2 섹션의 시작 부분 통합)

if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

disp('--- BS 간격 변화에 따른 네트워크 가용성 분석 시작 ---');
disp('----------------------------------------------------');

for idx = 1:length(bs_separation_m)
    d = bs_separation_m(idx);
    
    % d/2 거리를 lat/lon 단위로 변환하여 BS 위치 계산
    d_offset_lat = (d/2) * lat_per_m; 
    d_offset_lon = (d/2) * lon_per_m;

    % --- 4개의 BS 위치 정의 (d 간격의 정사각형 배치) ---
    bs_positions_lat = [lat_center + d_offset_lat, lat_center + d_offset_lat, lat_center - d_offset_lat, lat_center - d_offset_lat];
    bs_positions_lon = [lon_center + d_offset_lon, lon_center - d_offset_lon, lon_center + d_offset_lon, lon_center - d_offset_lon];

    num_bs = length(bs_positions_lat);
    bsSites(num_bs) = txsite; 
    for k = 1:num_bs
        bsSites(k) = txsite("Name", ['BS ', num2str(k)], ...
            "Latitude", bs_positions_lat(k), "Longitude", bs_positions_lon(k), ...
            "AntennaAngle", bsArrayOrientation(1:2), ...
            "AntennaHeight", tx_height, ...
            "TransmitterFrequency", fc, ...
            "TransmitterPower", tx_power_dbm);
    end
    
    % --- 핵심 계산: 다중 BS 신호 합산 (Max-Power) ---
    all_signal_strengths = zeros(numel(rxs), num_bs); % [격자점 개수 x BS 개수] 행렬
    
    disp(['  -> BS 간격 ', num2str(d), 'm 에 대한 Ray Tracing 계산 중...']);
    
    for k = 1:num_bs
        % k번째 BS에 대한 모든 rxs의 수신 전력 계산
        all_signal_strengths(:, k) = sigstrength(rxs, bsSites(k), pm);
    end

    % 각 격자점(행)에서 가장 강한 신호(열 방향의 최대값)를 선택 (Max-Power 결합)
    final_signal_strength = max(all_signal_strengths, [], 2);

    % --- 네트워크 가용성 계산 ---
    is_available = (final_signal_strength >= P_req);
    available_points = sum(is_available);
    Network_Availability = (available_points / total_points) * 100;
    
    % 결과 저장 및 출력
    availability_results(idx) = Network_Availability;
    disp(['  -> 계산 완료. 가용성: ', num2str(Network_Availability, '%.4f'), ' %']);
    
    % 99.999% 달성 시 루프 조기 종료
    if Network_Availability >= 99.999
        disp('⭐ 목표 가용성 99.999% 달성! 최적 간격 후보를 찾았습니다.');
        break; 
    end
end


%% 3. 최종 결과 시각화 및 분석

% 1. BS 간격-가용성 플롯
figure;
idx_to_plot = 1:idx;
plot(bs_separation_m(idx_to_plot), availability_results(idx_to_plot), 'r-o', 'LineWidth', 2);
xlabel('BS 배치 간격 (m)');
ylabel('네트워크 가용성 (%)');
title(['BS 간격 변화에 따른 네트워크 가용성 (P_{req}: ', num2str(P_req), ' dBm)']);
grid on;

hold on;
plot(bs_separation_m(idx_to_plot), ones(1, idx) * 99.999, 'b--', 'DisplayName', '목표 신뢰도 (99.999%)');
legend('계산된 가용성', '목표 신뢰도', 'Location', 'southwest');


% 2. 최종 간격에 대한 커버리지 맵 시각화 (최종 루프 결과 사용)
T = table(rx_positions_lat, rx_positions_lon, final_signal_strength, ...
          'VariableNames', {'Latitude', 'Longitude', 'SignalStrength'});
pd = propagationData(T);
pd.DataVariableName = 'SignalStrength'; 

% 이전 BS 위치를 지우고 최종 BS만 표시
clearMap(viewer);
show(bsSites); 

contour(pd, 'Type', 'power', 'Levels', [P_req], 'Transparency', 0.5);
title(['최종 간격 (', num2str(d), 'm) 네트워크 가용성 분석: ', num2str(Network_Availability, '%.2f'), '%']);
xlabel('Longitude'); ylabel('Latitude');


% 3. 최종 정량적 가이드라인 도출
disp(' ');
disp('==================================================');
disp('              🎉 최종 연구 결과 요약 🎉');
disp(['최소 수신 감도 (P_req): ', num2str(P_req), ' dBm']);
disp(' ');

optimal_idx = find(availability_results >= 99.999, 1, 'last');
if ~isempty(optimal_idx)
    optimal_d = bs_separation_m(optimal_idx);
    disp(['✅ 99.999% 이상을 만족하는 최적의 BS 배치 간격: ', num2str(optimal_d), ' m']);
    disp(['   (더 좁은 간격에서는 신뢰도가 상승하지만, ', num2str(optimal_d), 'm가 가장 넓은 경제적 간격임)']);
else
    disp('❌ 목표 가용성(99.999%)을 달성하는 간격을 찾지 못했습니다.');
    disp('   -> BS 간격 배열을 [50, 40, 30, 20] 등으로 더 좁게 설정하여 재실행하세요.');
end
disp('==================================================');