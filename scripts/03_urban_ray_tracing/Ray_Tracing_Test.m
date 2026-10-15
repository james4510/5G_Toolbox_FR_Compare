%% ====================================================================
%  기지국 설정
% =====================================================================

% 기지국 설정 시나리오
scenarios = {
    % 시나리오 1:
    struct('name', 'Small_Cell_Rooftop', ...
           'lat', 37.4515, 'lon', 127.1294, ...
           'height', 15, ...  % 15m
           'power', 30, ...   % 30W (44.8 dBm)
           'freq', 4.7e9, ...
           'antSize', [4 4], ...  % 4x4 안테나
           'antAngle', [0; -10])  % 방위각 0°, 하향 10°
    
    % 시나리오 2:
    struct('name', 'Macro_Cell', ...
           'lat', 37.4515, 'lon', 127.1294, ...
           'height', 25, ...  % 25m
           'power', 60, ...   % 60W (47.8 dBm)
           'freq', 4.7e9, ...
           'antSize', [8 8], ...  % 8x8 안테나
           'antAngle', [30; -15])  % 방위각 30°, 하향 15°
    
    % 시나리오 3:
    struct('name', 'High_Power_Tower', ...
           'lat', 37.4515, 'lon', 127.1294, ...
           'height', 40, ...  % 40m
           'power', 100, ...  % 100W (50 dBm)
           'freq', 4.7e9, ...
           'antSize', [16 8], ...  % 16x8 안테나
           'antAngle', [-45; -20])  % 방위각 -45°, 하향 20°
};

% 시나리오 선택
selectedScenario = 2;  % 1, 2, 3 중 선택 (0이면 전체)

if selectedScenario == 0
    scenariosToRun = 1:length(scenarios);
else
    scenariosToRun = selectedScenario;
end

% 반사 횟수
reflections = [0, 1, 2];

%% ====================================================================
%  SECTION 2: 거리별 측정 포인트 설정
% =====================================================================

% 거리별 측정 (20m ~ 300m, 20m 간격)
testDistances = 20:20:300;  % [20, 40, 60, ..., 300] m
numDistances = length(testDistances);

% 방향 (기지국 중심에서 방사형으로)
testAngles = [0, 45, 90, 135, 180, 225, 270, 315];  % 8방향
numAngles = length(testAngles);

fprintf('측정 설정:\n');
fprintf('  거리: %d ~ %d m (%d개 지점)\n', ...
        min(testDistances), max(testDistances), numDistances);
fprintf('  방향: %d개 방향\n', numAngles);
fprintf('  총 측정점: %d개\n\n', numDistances * numAngles);

%% ====================================================================
%  SECTION 3: 시뮬레이션 실행
% =====================================================================

% 결과 저장 구조체
results = cell(length(scenariosToRun), length(reflections));

for s_idx = 1:length(scenariosToRun)
    scenario = scenarios{scenariosToRun(s_idx)};
    
    fprintf('========================================\n');
    fprintf('시나리오: %s\n', scenario.name);
    fprintf('========================================\n');
    fprintf('위치: [%.6f, %.6f]\n', scenario.lat, scenario.lon);
    fprintf('높이: %.1f m\n', scenario.height);
    fprintf('송신 전력: %.1f W (%.1f dBm)\n', ...
            scenario.power, 10*log10(scenario.power*1000));
    fprintf('주파수: %.2f GHz\n', scenario.freq/1e9);
    fprintf('안테나: %dx%d\n', scenario.antSize(1), scenario.antSize(2));
    fprintf('안테나 각도: [%.0f°, %.0f°]\n\n', ...
            scenario.antAngle(1), scenario.antAngle(2));
    
    % Site Viewer
    viewer = siteviewer(Buildings="_seongnam_map.osm", Basemap="topographic");
    
    % 기지국 생성
    tx = txsite(Name=scenario.name, ...
        Latitude=scenario.lat, ...
        Longitude=scenario.lon, ...
        AntennaHeight=scenario.height, ...
        TransmitterPower=scenario.power, ...
        TransmitterFrequency=scenario.freq, ...
        AntennaAngle=scenario.antAngle);
    show(tx);
    
    % 반사 횟수별 시뮬레이션
    for r_idx = 1:length(reflections)
        numRefl = reflections(r_idx);
        
        fprintf('  ■ 반사 %d회 시뮬레이션\n', numRefl);
        
        % 전파 모델
        pm = propagationModel("raytracing", ...
            Method="sbr", ...
            MaxNumReflections=numRefl, ...
            MaxNumDiffractions=0, ...  % 회절 고정
            AngularSeparation="high", ...
            BuildingsMaterial="concrete", ...
            TerrainMaterial="concrete");
        
        % 거리별 측정
        fprintf('    측정 중: ');
        
        measuredPower = nan(numDistances, numAngles);
        measuredSNR = nan(numDistances, numAngles);
        hasPath = false(numDistances, numAngles);
        numPaths = zeros(numDistances, numAngles);
        hasLOS = false(numDistances, numAngles);
        
        tic;
        for d_idx = 1:numDistances
            if mod(d_idx, 5) == 0
                fprintf('%d ', testDistances(d_idx));
            end
            
            for a_idx = 1:numAngles
                % 측정 지점 좌표 계산
                distance = testDistances(d_idx);
                angle = testAngles(a_idx);
                
                % 위도/경도로 변환
                lat_per_m = 1 / 111000;
                lon_per_m = 1 / (111000 * cosd(scenario.lat));
                
                rx_lat = scenario.lat + distance * cosd(angle) * lat_per_m;
                rx_lon = scenario.lon + distance * sind(angle) * lon_per_m;
                
                % 수신기 생성
                rx = rxsite(Latitude=rx_lat, ...
                           Longitude=rx_lon, ...
                           AntennaHeight=1.5);
                
                % 레이 트레이싱 실행
                try
                    rays = raytrace(tx, rx, pm, "Type", "pathloss");
                    
                    if ~isempty(rays{1})
                        hasPath(d_idx, a_idx) = true;
                        numPaths(d_idx, a_idx) = length(rays{1});
                        hasLOS(d_idx, a_idx) = any([rays{1}.LineOfSight]);
                        
                        % 실제 측정값: 레이 트레이싱 경로 손실
                        pathLoss = rays{1}(1).PathLoss;
                        txPower_dBm = 10*log10(scenario.power * 1000);
                        
                        % 수신 전력 = 송신 전력 - 경로 손실
                        measuredPower(d_idx, a_idx) = txPower_dBm - pathLoss;
                        
                        % SNR 계산 (잡음: -91 dBm 가정, 40 MHz BW)
                        noisePower_dBm = -174 + 10*log10(40e6) + 7;
                        measuredSNR(d_idx, a_idx) = measuredPower(d_idx, a_idx) - noisePower_dBm;
                    end
                catch
                    % 경로를 찾지 못한 경우
                end
            end
        end
        elapsed = toc;
        fprintf('완료 (%.1f초)\n', elapsed);
        
        % 통계
        validPower = measuredPower(~isnan(measuredPower));
        validSNR = measuredSNR(~isnan(measuredSNR));
        
        fprintf('    측정 결과:\n');
        fprintf('      유효 측정: %d / %d (%.1f%%)\n', ...
                length(validPower), numel(measuredPower), ...
                length(validPower)/numel(measuredPower)*100);
        if ~isempty(validPower)
            fprintf('      평균 전력: %.2f dBm\n', mean(validPower));
            fprintf('      평균 SNR: %.2f dB\n', mean(validSNR));
            fprintf('      LOS 비율: %.1f%%\n', sum(hasLOS(:))/sum(hasPath(:))*100);
        end
        fprintf('\n');
        
        % 결과 저장
        result = struct();
        result.scenario = scenario;
        result.numReflections = numRefl;
        result.distances = testDistances;
        result.angles = testAngles;
        result.measuredPower = measuredPower;
        result.measuredSNR = measuredSNR;
        result.hasPath = hasPath;
        result.numPaths = numPaths;
        result.hasLOS = hasLOS;
        result.validPower = validPower;
        result.validSNR = validSNR;
        
        results{s_idx, r_idx} = result;
    end
    
    fprintf('\n');
end

