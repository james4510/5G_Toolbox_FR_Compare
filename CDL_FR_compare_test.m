%% FR1 vs FR2 분석: TDD Configuration 포함

clear; close all; clc;

%% ----- 사용자 설정 -----
% BS 설정
bsPosition = [37.455715, 127.133562]; % lat, lon (기지국)
bsAntennaSize = [4 4];
bsArrayOrientation = [90 0].';

% 송신 전력 설정 (dBm)
Pt_dBm = 30;

% 히트맵 설정
heatmap_radius_m = 200;  % BS로부터의 반경 (미터)
grid_resolution = 40;    % 각 차원의 그리드 포인트 수 (증가: 더 조밀)

% UE 원형 배치 설정
ue_distances = [15, 30, 45, 60, 75, 90];  % BS로부터의 거리 (미터)
ue_angular_spacing = 30;  % UE 간 각도 간격 (도)

% UE 안테나 파라미터
ueAntSize = [2 2];
ueArrayOrientation = [-30 45].';

% 반사 개수
reflectionsOrder = 1;

% 실험 주파수 및 대역폭
freqs = [4.7e9, 28e9];       % FR1, FR2
bws   = [100e6, 400e6];      % 대역폭
scs_list = [15e3, 120e3];    % Subcarrier Spacing

%% ----- TDD Configuration 설정 (특화망 유형별) -----
tdd_configs = struct();

% 1) DL-Heavy (영상 감시, 스트리밍) - DL 80%, UL 20%
tdd_configs(1).name = 'DL_Heavy';
tdd_configs(1).description = 'Video Surveillance/Streaming';
tdd_configs(1).DLULPeriodicity = 5;     % ms
tdd_configs(1).NumDLSlots = 7;
tdd_configs(1).NumDLSymbols = 12;
tdd_configs(1).NumULSlots = 2;
tdd_configs(1).NumULSymbols = 0;

% 2) Balanced (일반 통신) - DL 60%, UL 40%
tdd_configs(2).name = 'Balanced_60_40';
tdd_configs(2).description = 'General Communication';
tdd_configs(2).DLULPeriodicity = 5;     % ms
tdd_configs(2).NumDLSlots = 6;
tdd_configs(2).NumDLSymbols = 0;
tdd_configs(2).NumULSlots = 4;
tdd_configs(2).NumULSymbols = 0;

% 3) Balanced (공장 자동화) - DL 50%, UL 50%
tdd_configs(3).name = 'Balanced_50_50';
tdd_configs(3).description = 'Factory Automation';
tdd_configs(3).DLULPeriodicity = 2.5;   % ms (짧은 주기)
tdd_configs(3).NumDLSlots = 2;
tdd_configs(3).NumDLSymbols = 12;
tdd_configs(3).NumULSlots = 2;
tdd_configs(3).NumULSymbols = 1;

% 4) UL-Heavy (센서 데이터, IoT) - DL 30%, UL 70%
tdd_configs(4).name = 'UL_Heavy';
tdd_configs(4).description = 'IoT/Sensor Networks';
tdd_configs(4).DLULPeriodicity = 5;     % ms
tdd_configs(4).NumDLSlots = 3;
tdd_configs(4).NumDLSymbols = 0;
tdd_configs(4).NumULSlots = 7;
tdd_configs(4).NumULSymbols = 0;

% Default TDD config (Balanced 50:50)
default_tdd_idx = 3;

% SNR 임계값
SNR_thresholds = [0, 5, 10, 15, 20];

% OFDM 설정
SCS = 15; NRB = 52;

% 출력 파일명
outCSV_points = "results_FR1_FR2_points.csv";
outCSV_heatmap = "results_FR1_FR2_heatmap.csv";
outCSV_coverage = "results_FR1_FR2_coverage_stats.csv";
outCSV_ue_coordinates = "ue_coordinates.csv";
outCSV_tdd_comparison = "results_TDD_comparison.csv";
outCSV_tdd_distance = "results_TDD_vs_distance.csv";

%% ----- 좌표 변환 함수 -----
meters_to_lat = @(m) m / 111000;
meters_to_lon = @(m, lat) m / (111000 * cosd(lat));
latlon_to_meters = @(lat1, lon1, lat2, lon2) distance(lat1, lon1, lat2, lon2) * 1000;

function [new_lat, new_lon] = offset_position(base_lat, base_lon, distance_m, bearing_deg)
    delta_lat_m = distance_m * cosd(bearing_deg);
    delta_lat = delta_lat_m / 111000;
    delta_lon_m = distance_m * sind(bearing_deg);
    delta_lon = delta_lon_m / (111000 * cosd(base_lat));
    new_lat = base_lat + delta_lat;
    new_lon = base_lon + delta_lon;
end

fprintf("========================================================\n");
fprintf("    FR1 vs FR2 Coverage Analysis with TDD\n");
fprintf("========================================================\n");

%% ----- TDD Configuration 정보 출력 -----
fprintf("\nTDD Configuration Settings:\n");
fprintf("%-18s %-30s %8s %8s %10s\n", 'Config', 'Description', 'DL%', 'UL%', 'Period(ms)');
fprintf("--------------------------------------------------------------------------------\n");

for cfg_idx = 1:length(tdd_configs)
    cfg = tdd_configs(cfg_idx);
    
    % DL/UL 비율 계산
    total_slots = cfg.NumDLSlots + cfg.NumULSlots;
    dl_ratio = cfg.NumDLSlots / total_slots * 100;
    ul_ratio = cfg.NumULSlots / total_slots * 100;
    
    fprintf("%-18s %-30s %7.1f%% %7.1f%% %10.1f\n", ...
        cfg.name, cfg.description, dl_ratio, ul_ratio, cfg.DLULPeriodicity);
end

fprintf("\nDefault TDD Config for heatmap analysis: %s\n", tdd_configs(default_tdd_idx).name);

%% ----- UE 좌표 생성 -----
fprintf("\n========================================================\n");
fprintf("STEP 1: UE Coordinate Generation\n");
fprintf("========================================================\n");
fprintf("  BS Position: (%.6f, %.6f)\n", bsPosition(1), bsPosition(2));
fprintf("  Distances: %s m\n", mat2str(ue_distances));
fprintf("  Angular spacing: %d degrees\n", ue_angular_spacing);

uePoints = [];
ue_info = table();
point_idx = 0;

for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    num_ues_at_distance = floor(360 / ue_angular_spacing);
    
    fprintf("  Distance %dm: %d UEs\n", dist, num_ues_at_distance);
    
    for angle_idx = 1:num_ues_at_distance
        point_idx = point_idx + 1;
        bearing_deg = (angle_idx - 1) * ue_angular_spacing;
        [ue_lat, ue_lon] = offset_position(bsPosition(1), bsPosition(2), dist, bearing_deg);
        actual_distance = latlon_to_meters(bsPosition(1), bsPosition(2), ue_lat, ue_lon);
        distance_error = abs(actual_distance - dist);
        
        uePoints = [uePoints; ue_lat, ue_lon];
        
        ue_info_row = struct('UE_ID', point_idx, 'Distance_m', dist, ...
            'Bearing_deg', bearing_deg, 'Latitude', ue_lat, 'Longitude', ue_lon, ...
            'Actual_Distance_m', actual_distance, 'Distance_Error_m', distance_error);
        ue_info = [ue_info; struct2table(ue_info_row)];
    end
end

fprintf("  Total Generated: %d UE coordinates\n", size(uePoints, 1));
fprintf("  Average distance error: %.3f m\n", mean(ue_info.Distance_Error_m));
writetable(ue_info, outCSV_ue_coordinates);

%% ----- UE 배치 패턴 시각화 -----
fprintf("\n========================================================\n");
fprintf("STEP 2: UE Deployment Visualization\n");
fprintf("========================================================\n");

fig1 = figure('Name', 'UE Deployment Pattern', 'Position', [100 100 1000 900], ...
    'Color', 'w', 'Visible', 'off');

% Geographic coordinates
subplot(2,1,1);
hold on; grid on; box on;
plot(bsPosition(2), bsPosition(1), '^', 'MarkerSize', 14, ...
    'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

colors = lines(length(ue_distances));
for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    ues_at_dist = uePoints(ue_info.Distance_m == dist, :);
    plot(ues_at_dist(:,2), ues_at_dist(:,1), 'o', ...
        'Color', colors(dist_idx,:), 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(dist_idx,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%dm (%d UEs)', dist, size(ues_at_dist, 1)));
end

for dist = ue_distances
    theta = linspace(0, 2*pi, 100);
    circle_lat_radius = meters_to_lat(dist);
    circle_lon_radius = meters_to_lon(dist, bsPosition(1));
    circle_lats = bsPosition(1) + circle_lat_radius * cos(theta);
    circle_lons = bsPosition(2) + circle_lon_radius * sin(theta);
    plot(circle_lons, circle_lats, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
end

xlabel('Longitude', 'FontSize', 11, 'FontName', 'Arial');
ylabel('Latitude', 'FontSize', 11, 'FontName', 'Arial');
title('Geographic Coordinates', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'normal');
legend('Location', 'bestoutside', 'FontSize', 9);
axis equal;
set(gca, 'FontSize', 10, 'FontName', 'Arial');
hold off;

% Relative coordinates
subplot(2,1,2);
hold on; grid on; box on;
plot(0, 0, '^', 'MarkerSize', 14, 'MarkerFaceColor', [1 0 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    ues_at_dist_info = ue_info(ue_info.Distance_m == dist, :);
    x = dist * sind(ues_at_dist_info.Bearing_deg);
    y = dist * cosd(ues_at_dist_info.Bearing_deg);
    plot(x, y, 'o', 'Color', colors(dist_idx,:), 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(dist_idx,:), 'LineWidth', 1.2);
end

for dist = ue_distances
    theta = linspace(0, 2*pi, 100);
    plot(dist*sin(theta), dist*cos(theta), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
end

max_dist = max(ue_distances) * 1.1;
xlabel('East-West Distance (m)', 'FontSize', 11, 'FontName', 'Arial');
ylabel('North-South Distance (m)', 'FontSize', 11, 'FontName', 'Arial');
title('Relative Coordinates (BS at Origin)', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'normal');
axis equal;
xlim([-max_dist, max_dist]);
ylim([-max_dist, max_dist]);
set(gca, 'FontSize', 10, 'FontName', 'Arial');
hold off;

saveas(fig1, 'UE_Deployment_Pattern.png');
fprintf("  Created: UE_Deployment_Pattern.png\n");

%% ----- Siteviewer 초기화 -----
fprintf("\n========================================================\n");
fprintf("STEP 3: Siteviewer Initialization\n");
fprintf("========================================================\n");

if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

lat_delta = meters_to_lat(heatmap_radius_m);
lon_delta = meters_to_lon(heatmap_radius_m, bsPosition(1));
lat_range = [bsPosition(1) - lat_delta, bsPosition(1) + lat_delta];
lon_range = [bsPosition(2) - lon_delta, bsPosition(2) + lon_delta];

fprintf("  Heatmap range: +/-%dm from BS\n", heatmap_radius_m);
fprintf("  Grid resolution: %dx%d points\n", grid_resolution, grid_resolution);

% BS site
fc_init = freqs(1);
bsSite = txsite("Name","Base Station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2),...
    "AntennaAngle",bsArrayOrientation(1:2),...
    "AntennaHeight",16,...
    "TransmitterFrequency",fc_init);
show(bsSite);

% UE sites
rxSites = cell(size(uePoints, 1), 1);
for p = 1:size(uePoints, 1)
    lat = uePoints(p, 1);
    lon = uePoints(p, 2);
    rxSites{p} = rxsite("Name", sprintf("UE_%d", p), ...
        "Latitude", lat, "Longitude", lon, ...
        "AntennaHeight", 1, ...
        "AntennaAngle", ueArrayOrientation(1:2));
    show(rxSites{p});
    if mod(p, 15) == 0
        fprintf("  Created %d/%d UE sites\n", p, size(uePoints, 1));
    end
end

fprintf("  All UE sites displayed in Siteviewer\n");

%% ----- 준비 -----
c = physconst('LightSpeed');
ofdmInfo = nrOFDMInfo(NRB,SCS);

results_points = table();
results_heatmap = table();
coverage_stats = table();

% ★★★ 테이블 명시적 초기화 (오류 수정의 핵심!) ★★★
% TDD 비교 결과 테이블
varTypes_tdd = {'double', 'string', 'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double'};
varNames_tdd = {'Frequency_GHz', 'TDD_Config', 'DL_Ratio', 'UL_Ratio', ...
    'Distance_m', 'UE_ID', 'SNR_dB', 'Throughput_DL_Mbps', ...
    'Throughput_UL_Mbps', 'Throughput_Total_Mbps'};
results_tdd = table('Size', [0 length(varNames_tdd)], ...
    'VariableTypes', varTypes_tdd, 'VariableNames', varNames_tdd);

% TDD 거리별 성능 테이블
varTypes_dist = {'string', 'double', 'double', 'double', 'double'};
varNames_dist = {'TDD_Config', 'Distance_m', 'Avg_Throughput_DL_Mbps', ...
    'Avg_Throughput_UL_Mbps', 'Avg_Throughput_Total_Mbps'};
results_tdd_distance = table('Size', [0 length(varNames_dist)], ...
    'VariableTypes', varTypes_dist, 'VariableNames', varNames_dist);

lat_grid = linspace(lat_range(1), lat_range(2), grid_resolution);
lon_grid = linspace(lon_range(1), lon_range(2), grid_resolution);
[LON_GRID, LAT_GRID] = meshgrid(lon_grid, lat_grid);

%% ===== PART 1: UE 포인트 분석 (TDD 고려) =====
fprintf("\n========================================================\n");
fprintf("PART 1: UE Point Analysis with TDD (Ray Tracing)\n");
fprintf("========================================================\n");

rowIdx = 0;

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    scs = scs_list(fIdx);
    fprintf("\nFrequency: %.3f GHz (BW = %.1f MHz, SCS = %.1f kHz)\n", ...
        fc/1e9, bw/1e6, scs/1e3);
    
    bsSite.TransmitterFrequency = fc;
    lambda = c / fc;
    
    bsArray = phased.NRRectangularPanelArray('Size',[bsAntennaSize(1:2) 1 1], ...
        'Spacing',[0.5*lambda*[1 1] 1 1]);
    bsArray.ElementSet = {phased.NRAntennaElement};
    
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
    kB = 1.38064852e-23; T = 290;
    Noise_W = kB * T * bw;
    Noise_dBm = 10*log10(Noise_W) + 30;
    
    % Default TDD config 사용
    cfg = tdd_configs(default_tdd_idx);
    total_slots = cfg.NumDLSlots + cfg.NumULSlots;
    dl_ratio = cfg.NumDLSlots / total_slots;
    ul_ratio = cfg.NumULSlots / total_slots;
    
    fprintf("Using TDD Config: %s (DL %.0f%%, UL %.0f%%)\n", ...
        cfg.name, dl_ratio*100, ul_ratio*100);
    fprintf("Analyzing %d UE points...\n", size(uePoints,1));
    
    tic;
    
    for p = 1:size(uePoints,1)
        rowIdx = rowIdx + 1;
        lat = uePoints(p,1); 
        lon = uePoints(p,2);
        ue_dist = ue_info.Distance_m(p);
        ue_angle = ue_info.Bearing_deg(p);
        
        if mod(p, 12) == 0 || p == 1 || p == size(uePoints,1)
            elapsed = toc;
            eta = elapsed / p * (size(uePoints,1) - p);
            fprintf("  Progress: %d/%d (%.1f%%, ETA: %.1fs)\n", ...
                p, size(uePoints,1), p/size(uePoints,1)*100, eta);
        end
        
        rx = rxSites{p};
        rays = raytrace(bsSite, rx, pm, "Type","pathloss");
        
        if isempty(rays) || isempty(rays{1})
            row = struct('fc', fc, 'UE_ID', p, 'distance_m', ue_dist, ...
                'bearing_deg', ue_angle, 'lat', lat, 'lon', lon, ...
                'TDD_Config', string(cfg.name), 'DL_ratio', dl_ratio, 'UL_ratio', ul_ratio, ...
                'LOS', false, 'numPaths', 0, 'Pr_dBm', NaN, ...
                'Noise_dBm', NaN, 'SNR_dB', NaN, ...
                'Throughput_DL_bps', NaN, 'Throughput_UL_bps', NaN, ...
                'Throughput_Total_bps', NaN, 'delaySpread_s', NaN);
            results_points = [results_points; struct2table(row)]; %#ok<AGROW>
            continue;
        end
        
        pathDelays = [rays{1}.PropagationDelay] - min([rays{1}.PropagationDelay]);
        pathLosses = [rays{1}.PathLoss];
        avgPathGains_dB = -pathLosses;
        isLOS = any([rays{1}.LineOfSight]);
        numPaths = numel(pathDelays);
        
        pathGains_lin = 10.^(avgPathGains_dB./10);
        Pt_mW = 10^(Pt_dBm/10);
        Pr_mW = Pt_mW * sum(pathGains_lin);
        Pr_dBm = 10*log10(Pr_mW);
        
        SNR_dB = Pr_dBm - Noise_dBm;
        SNR_lin = 10^(SNR_dB/10);
        
        % TDD 고려한 Effective Bandwidth
        effective_bw_dl = bw * dl_ratio;
        effective_bw_ul = bw * ul_ratio;
        
        % DL/UL Throughput (Shannon Capacity)
        throughput_dl_bps = effective_bw_dl * log2(1 + SNR_lin);
        throughput_ul_bps = effective_bw_ul * log2(1 + SNR_lin);
        throughput_total_bps = throughput_dl_bps + throughput_ul_bps;
        
        P_sum = sum(pathGains_lin);
        if P_sum > 0
            tau_mean = sum(pathDelays .* pathGains_lin) / P_sum;
            tau_rms = sqrt( sum( ((pathDelays - tau_mean).^2) .* pathGains_lin ) / P_sum );
        else
            tau_rms = NaN;
        end
        
        row = struct('fc', fc, 'UE_ID', p, 'distance_m', ue_dist, ...
            'bearing_deg', ue_angle, 'lat', lat, 'lon', lon, ...
            'TDD_Config', string(cfg.name), 'DL_ratio', dl_ratio, 'UL_ratio', ul_ratio, ...
            'LOS', isLOS, 'numPaths', numPaths, 'Pr_dBm', Pr_dBm, ...
            'Noise_dBm', Noise_dBm, 'SNR_dB', SNR_dB, ...
            'Throughput_DL_bps', throughput_dl_bps, ...
            'Throughput_UL_bps', throughput_ul_bps, ...
            'Throughput_Total_bps', throughput_total_bps, ...
            'delaySpread_s', tau_rms);
        results_points = [results_points; struct2table(row)]; %#ok<AGROW>
    end
    
    computation_time = toc;
    fprintf("Completed in %.1f seconds\n", computation_time);
end

writetable(results_points, outCSV_points);
fprintf("\nSaved: %s\n", outCSV_points);

%% ===== PART 2: TDD Configuration 비교 분석 =====
fprintf("\n========================================================\n");
fprintf("PART 2: TDD Configuration Comparison Analysis\n");
fprintf("========================================================\n");

% 대표 거리 선택 (중간 거리)
representative_distance = 45;  % meters
rep_ues = ue_info(ue_info.Distance_m == representative_distance, :);

fprintf("Comparing TDD configurations at %dm distance...\n", representative_distance);
fprintf("Number of UEs at this distance: %d\n\n", height(rep_ues));

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    freq_label = sprintf('%.1f GHz', fc/1e9);
    
    fprintf("Frequency: %s\n", freq_label);
    fprintf("%-18s %12s %12s %12s\n", 'TDD Config', 'Avg DL(Mbps)', 'Avg UL(Mbps)', 'Total(Mbps)');
    fprintf("----------------------------------------------------------\n");
    
    bsSite.TransmitterFrequency = fc;
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
    kB = 1.38064852e-23; T = 290;
    Noise_W = kB * T * bw;
    Noise_dBm = 10*log10(Noise_W) + 30;
    
    for cfg_idx = 1:length(tdd_configs)
        cfg = tdd_configs(cfg_idx);
        
        % DL/UL 비율
        total_slots = cfg.NumDLSlots + cfg.NumULSlots;
        dl_ratio = cfg.NumDLSlots / total_slots;
        ul_ratio = cfg.NumULSlots / total_slots;
        
        % Effective Bandwidth
        effective_bw_dl = bw * dl_ratio;
        effective_bw_ul = bw * ul_ratio;
        
        % 대표 UE들에 대해 계산
        sum_tp_dl = 0;
        sum_tp_ul = 0;
        valid_count = 0;
        
        for ue_idx = 1:height(rep_ues)
            ue_id = rep_ues.UE_ID(ue_idx);
            rx = rxSites{ue_id};
            
            rays = raytrace(bsSite, rx, pm, "Type","pathloss");
            if isempty(rays) || isempty(rays{1})
                continue;
            end
            
            pathLosses = [rays{1}.PathLoss];
            avgPathGains_dB = -pathLosses;
            pathGains_lin = 10.^(avgPathGains_dB./10);
            
            Pt_mW = 10^(Pt_dBm/10);
            Pr_mW = Pt_mW * sum(pathGains_lin);
            Pr_dBm = 10*log10(Pr_mW);
            
            SNR_dB = Pr_dBm - Noise_dBm;
            SNR_lin = 10^(SNR_dB/10);
            
            tp_dl = effective_bw_dl * log2(1 + SNR_lin);
            tp_ul = effective_bw_ul * log2(1 + SNR_lin);
            
            sum_tp_dl = sum_tp_dl + tp_dl;
            sum_tp_ul = sum_tp_ul + tp_ul;
            valid_count = valid_count + 1;
            
            % ★★★ string() 함수 사용 (오류 수정!) ★★★
            row_tdd = struct('Frequency_GHz', fc/1e9, ...
                'TDD_Config', string(cfg.name), ...
                'DL_Ratio', dl_ratio, 'UL_Ratio', ul_ratio, ...
                'Distance_m', representative_distance, ...
                'UE_ID', ue_id, ...
                'SNR_dB', SNR_dB, ...
                'Throughput_DL_Mbps', tp_dl/1e6, ...
                'Throughput_UL_Mbps', tp_ul/1e6, ...
                'Throughput_Total_Mbps', (tp_dl+tp_ul)/1e6);
            results_tdd = [results_tdd; struct2table(row_tdd)]; %#ok<AGROW>
        end
        
        if valid_count > 0
            avg_tp_dl = sum_tp_dl / valid_count / 1e6;
            avg_tp_ul = sum_tp_ul / valid_count / 1e6;
            avg_tp_total = avg_tp_dl + avg_tp_ul;
            
            fprintf("%-18s %12.1f %12.1f %12.1f\n", ...
                cfg.name, avg_tp_dl, avg_tp_ul, avg_tp_total);
        end
    end
    fprintf("\n");
end

writetable(results_tdd, outCSV_tdd_comparison);
fprintf("Saved: %s\n\n", outCSV_tdd_comparison);

%% ===== PART 3: TDD별 거리별 성능 분석 (FR2만) =====
fprintf("\n========================================================\n");
fprintf("PART 3: TDD Performance vs Distance (FR2 only)\n");
fprintf("========================================================\n");

fc_fr2 = freqs(2);
bw_fr2 = bws(2);
freq_label = 'FR2 (28 GHz)';

fprintf("Analyzing %s with different TDD configs...\n\n", freq_label);

bsSite.TransmitterFrequency = fc_fr2;
pm = propagationModel("raytracing","Method","sbr", ...
    "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);

kB = 1.38064852e-23; T = 290;
Noise_W = kB * T * bw_fr2;
Noise_dBm = 10*log10(Noise_W) + 30;

unique_distances = unique(ue_info.Distance_m);

for cfg_idx = 1:length(tdd_configs)
    cfg = tdd_configs(cfg_idx);
    
    fprintf("TDD Config: %s\n", cfg.name);
    
    total_slots = cfg.NumDLSlots + cfg.NumULSlots;
    dl_ratio = cfg.NumDLSlots / total_slots;
    ul_ratio = cfg.NumULSlots / total_slots;
    
    effective_bw_dl = bw_fr2 * dl_ratio;
    effective_bw_ul = bw_fr2 * ul_ratio;
    
    for dist_idx = 1:length(unique_distances)
        dist = unique_distances(dist_idx);
        ues_at_dist = ue_info(ue_info.Distance_m == dist, :);
        
        sum_tp_dl = 0;
        sum_tp_ul = 0;
        count = 0;
        
        for ue_idx = 1:height(ues_at_dist)
            ue_id = ues_at_dist.UE_ID(ue_idx);
            rx = rxSites{ue_id};
            
            rays = raytrace(bsSite, rx, pm, "Type","pathloss");
            if isempty(rays) || isempty(rays{1})
                continue;
            end
            
            pathLosses = [rays{1}.PathLoss];
            avgPathGains_dB = -pathLosses;
            pathGains_lin = 10.^(avgPathGains_dB./10);
            
            Pt_mW = 10^(Pt_dBm/10);
            Pr_mW = Pt_mW * sum(pathGains_lin);
            Pr_dBm = 10*log10(Pr_mW);
            
            SNR_dB = Pr_dBm - Noise_dBm;
            SNR_lin = 10^(SNR_dB/10);
            
            tp_dl = effective_bw_dl * log2(1 + SNR_lin);
            tp_ul = effective_bw_ul * log2(1 + SNR_lin);
            
            sum_tp_dl = sum_tp_dl + tp_dl;
            sum_tp_ul = sum_tp_ul + tp_ul;
            count = count + 1;
        end
        
        if count > 0
            avg_tp_dl = sum_tp_dl / count / 1e6;
            avg_tp_ul = sum_tp_ul / count / 1e6;
            
            % ★★★ string() 함수 사용 (오류 수정!) ★★★
            row_dist = struct('TDD_Config', string(cfg.name), ...
                'Distance_m', dist, ...
                'Avg_Throughput_DL_Mbps', avg_tp_dl, ...
                'Avg_Throughput_UL_Mbps', avg_tp_ul, ...
                'Avg_Throughput_Total_Mbps', avg_tp_dl + avg_tp_ul);
            results_tdd_distance = [results_tdd_distance; struct2table(row_dist)]; %#ok<AGROW>
        end
    end
    
    fprintf("  Completed\n");
end

writetable(results_tdd_distance, outCSV_tdd_distance);
fprintf("\nSaved: %s\n", outCSV_tdd_distance);

%% ===== PART 4: 히트맵 생성 (Default TDD 사용) =====
fprintf("\n========================================================\n");
fprintf("PART 4: Coverage Heatmap Generation (Default TDD)\n");
fprintf("========================================================\n");

SNR_maps = cell(length(freqs), 1);
Pr_maps = cell(length(freqs), 1);
TP_DL_maps = cell(length(freqs), 1);
TP_UL_maps = cell(length(freqs), 1);
distance_map = nan(size(LAT_GRID));

fprintf("Computing distance map...\n");
for i = 1:size(LAT_GRID,1)
    for j = 1:size(LAT_GRID,2)
        lat = LAT_GRID(i,j);
        lon = LON_GRID(i,j);
        distance_map(i,j) = latlon_to_meters(bsPosition(1), bsPosition(2), lat, lon);
    end
end

heatmap_figs = cell(length(freqs) * 3, 1);
fig_idx = 0;

cfg_default = tdd_configs(default_tdd_idx);
total_slots = cfg_default.NumDLSlots + cfg_default.NumULSlots;
dl_ratio = cfg_default.NumDLSlots / total_slots;
ul_ratio = cfg_default.NumULSlots / total_slots;

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    freq_label = sprintf('%.1f GHz', fc/1e9);
    fprintf("\nHeatmap: %s (TDD: %s)\n", freq_label, cfg_default.name);
    
    bsSite.TransmitterFrequency = fc;
    lambda = c / fc;
    
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
    SNR_map = nan(size(LAT_GRID));
    Pr_map = nan(size(LAT_GRID));
    TP_DL_map = nan(size(LAT_GRID));
    TP_UL_map = nan(size(LAT_GRID));
    
    kB = 1.38064852e-23; T = 290;
    Noise_W = kB * T * bw;
    Noise_dBm = 10*log10(Noise_W) + 30;
    
    effective_bw_dl = bw * dl_ratio;
    effective_bw_ul = bw * ul_ratio;
    
    total_points = numel(LAT_GRID);
    fprintf("Computing %d grid points...\n", total_points);
    
    tic;
    for i = 1:size(LAT_GRID,1)
        if mod(i,5)==0
            elapsed = toc;
            eta = elapsed / i * (size(LAT_GRID,1) - i);
            fprintf("  Progress: %d/%d rows (%.1f%%, ETA: %.1fs)\n", ...
                i, size(LAT_GRID,1), i/size(LAT_GRID,1)*100, eta);
        end
        for j = 1:size(LAT_GRID,2)
            lat = LAT_GRID(i,j);
            lon = LON_GRID(i,j);
            
            rx_temp = rxsite("Latitude", lat, "Longitude", lon, ...
                "AntennaHeight", 1, "AntennaAngle", ueArrayOrientation(1:2));
            
            rays = raytrace(bsSite, rx_temp, pm, "Type","pathloss");
            
            if isempty(rays) || isempty(rays{1})
                continue;
            end
            
            pathLosses = [rays{1}.PathLoss];
            avgPathGains_dB = -pathLosses;
            pathGains_lin = 10.^(avgPathGains_dB./10);
            
            Pt_mW = 10^(Pt_dBm/10);
            Pr_mW = Pt_mW * sum(pathGains_lin);
            Pr_dBm_val = 10*log10(Pr_mW);
            
            SNR_dB_val = Pr_dBm_val - Noise_dBm;
            SNR_lin_val = 10^(SNR_dB_val/10);
            
            % TDD 고려한 Throughput
            throughput_dl_bps = effective_bw_dl * log2(1 + SNR_lin_val);
            throughput_ul_bps = effective_bw_ul * log2(1 + SNR_lin_val);
            
            Pr_map(i,j) = Pr_dBm_val;
            SNR_map(i,j) = SNR_dB_val;
            TP_DL_map(i,j) = throughput_dl_bps / 1e6;
            TP_UL_map(i,j) = throughput_ul_bps / 1e6;
            
            % ★★★ string() 함수 사용 (오류 수정!) ★★★
            row_hm = struct('fc', fc, 'lat', lat, 'lon', lon, ...
                'distance_m', distance_map(i,j), ...
                'TDD_Config', string(cfg_default.name), ...
                'Pr_dBm', Pr_dBm_val, 'SNR_dB', SNR_dB_val, ...
                'Throughput_DL_Mbps', throughput_dl_bps/1e6, ...
                'Throughput_UL_Mbps', throughput_ul_bps/1e6);
            results_heatmap = [results_heatmap; struct2table(row_hm)]; %#ok<AGROW>
        end
    end
    
    computation_time = toc;
    fprintf("Completed in %.1f seconds\n", computation_time);
    
    SNR_maps{fIdx} = SNR_map;
    Pr_maps{fIdx} = Pr_map;
    TP_DL_maps{fIdx} = TP_DL_map;
    TP_UL_maps{fIdx} = TP_UL_map;
    
    %% SNR 히트맵
    fig_idx = fig_idx + 1;
    heatmap_figs{fig_idx} = figure('Name', sprintf('SNR Heatmap - %s', freq_label), ...
        'Position', [100 100 800 600], 'Color', 'w', 'Visible', 'off');
    
    imagesc(lon_grid, lat_grid, SNR_map);
    set(gca, 'YDir', 'normal');
    colormap(gca, 'jet');
    caxis([-10 30]);
    
    cb = colorbar;
    cb.Label.String = 'SNR (dB)';
    cb.FontSize = 10;
    cb.LineWidth = 1;
    
    xlabel('Longitude', 'FontSize', 11);
    ylabel('Latitude', 'FontSize', 11);
    title(sprintf('SNR Heatmap - %s (%s)', freq_label, cfg_default.name), ...
        'FontSize', 12, 'FontWeight', 'normal');
    
    hold on;
    plot(bsPosition(2), bsPosition(1), '^', 'MarkerSize', 12, ...
        'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', 'none');
    plot(uePoints(:,2), uePoints(:,1), 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');
    hold off;
    
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    axis equal tight;
    box on;
    
    saveas(heatmap_figs{fig_idx}, sprintf('SNR_Heatmap_%s.png', strrep(freq_label, ' ', '_')), 'png');
    
    %% DL Throughput 히트맵
    fig_idx = fig_idx + 1;
    heatmap_figs{fig_idx} = figure('Name', sprintf('DL Throughput - %s', freq_label), ...
        'Position', [150 150 800 600], 'Color', 'w', 'Visible', 'off');
    
    imagesc(lon_grid, lat_grid, TP_DL_map);
    set(gca, 'YDir', 'normal');
    colormap(gca, 'hot');
    
    cb = colorbar;
    cb.Label.String = 'Throughput (Mbps)';
    cb.FontSize = 10;
    cb.LineWidth = 1;
    
    xlabel('Longitude', 'FontSize', 11);
    ylabel('Latitude', 'FontSize', 11);
    title(sprintf('DL Throughput - %s (%s, DL %.0f%%)', freq_label, ...
        cfg_default.name, dl_ratio*100), 'FontSize', 12, 'FontWeight', 'normal');
    
    hold on;
    plot(bsPosition(2), bsPosition(1), '^', 'MarkerSize', 12, ...
        'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', 'none');
    plot(uePoints(:,2), uePoints(:,1), 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');
    hold off;
    
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    axis equal tight;
    box on;
    
    saveas(heatmap_figs{fig_idx}, sprintf('DL_Throughput_%s.png', strrep(freq_label, ' ', '_')), 'png');
    
    %% UL Throughput 히트맵
    fig_idx = fig_idx + 1;
    heatmap_figs{fig_idx} = figure('Name', sprintf('UL Throughput - %s', freq_label), ...
        'Position', [200 200 800 600], 'Color', 'w', 'Visible', 'off');
    
    imagesc(lon_grid, lat_grid, TP_UL_map);
    set(gca, 'YDir', 'normal');
    colormap(gca, 'parula');
    
    cb = colorbar;
    cb.Label.String = 'Throughput (Mbps)';
    cb.FontSize = 10;
    cb.LineWidth = 1;
    
    xlabel('Longitude', 'FontSize', 11);
    ylabel('Latitude', 'FontSize', 11);
    title(sprintf('UL Throughput - %s (%s, UL %.0f%%)', freq_label, ...
        cfg_default.name, ul_ratio*100), 'FontSize', 12, 'FontWeight', 'normal');
    
    hold on;
    plot(bsPosition(2), bsPosition(1), '^', 'MarkerSize', 12, ...
        'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', 'none');
    plot(uePoints(:,2), uePoints(:,1), 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');
    hold off;
    
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    axis equal tight;
    box on;
    
    saveas(heatmap_figs{fig_idx}, sprintf('UL_Throughput_%s.png', strrep(freq_label, ' ', '_')), 'png');
    
    % 커버리지 통계
    fprintf("\nCoverage Statistics - %s:\n", freq_label);
    for thr = SNR_thresholds
        valid_points = ~isnan(SNR_map);
        total_valid = sum(valid_points(:));
        covered = sum(SNR_map(valid_points) >= thr);
        coverage_ratio = covered / total_valid * 100;
        
        stat_row = struct('fc', fc, 'SNR_threshold_dB', thr, ...
            'total_points', total_valid, 'covered_points', covered, ...
            'coverage_ratio_percent', coverage_ratio);
        coverage_stats = [coverage_stats; struct2table(stat_row)]; %#ok<AGROW>
        
        fprintf("  SNR >= %2d dB: %6.2f%% (%d/%d)\n", ...
            thr, coverage_ratio, covered, total_valid);
    end
end

writetable(results_heatmap, outCSV_heatmap);
writetable(coverage_stats, outCSV_coverage);
fprintf("\nSaved: %s\n", outCSV_heatmap);
fprintf("Saved: %s\n", outCSV_coverage);

%% ===== PART 5: 거리별 성능 분석 =====
fprintf("\n========================================================\n");
fprintf("PART 5: Performance vs Distance (Default TDD)\n");
fprintf("========================================================\n");

fig_perf = figure('Name','Performance vs Distance', 'Position', [100 100 1400 400], ...
    'Color', 'w', 'Visible', 'off');

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    data_f = results_points(results_points.fc == fc, :);
    
    unique_distances = unique(data_f.distance_m);
    avg_snr = zeros(length(unique_distances), 1);
    avg_tp_dl = zeros(length(unique_distances), 1);
    avg_tp_ul = zeros(length(unique_distances), 1);
    avg_pr = zeros(length(unique_distances), 1);
    
    for d_idx = 1:length(unique_distances)
        dist = unique_distances(d_idx);
        data_dist = data_f(data_f.distance_m == dist, :);
        avg_snr(d_idx) = mean(data_dist.SNR_dB, 'omitnan');
        avg_tp_dl(d_idx) = mean(data_dist.Throughput_DL_bps / 1e6, 'omitnan');
        avg_tp_ul(d_idx) = mean(data_dist.Throughput_UL_bps / 1e6, 'omitnan');
        avg_pr(d_idx) = mean(data_dist.Pr_dBm, 'omitnan');
    end
    
    % SNR
    subplot(1,4,1);
    if fIdx == 1
        plot(unique_distances, avg_snr, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(unique_distances, avg_snr, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance (m)', 'FontSize', 11);
    ylabel('Avg SNR (dB)', 'FontSize', 11);
    title('SNR vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    box on;
    
    % DL Throughput
    subplot(1,4,2);
    if fIdx == 1
        plot(unique_distances, avg_tp_dl, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(unique_distances, avg_tp_dl, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance (m)', 'FontSize', 11);
    ylabel('Avg DL Throughput (Mbps)', 'FontSize', 11);
    title('DL Throughput vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    box on;
    
    % UL Throughput
    subplot(1,4,3);
    if fIdx == 1
        plot(unique_distances, avg_tp_ul, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(unique_distances, avg_tp_ul, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance (m)', 'FontSize', 11);
    ylabel('Avg UL Throughput (Mbps)', 'FontSize', 11);
    title('UL Throughput vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    box on;
    
    % Rx Power
    subplot(1,4,4);
    if fIdx == 1
        plot(unique_distances, avg_pr, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(unique_distances, avg_pr, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance (m)', 'FontSize', 11);
    ylabel('Avg Rx Power (dBm)', 'FontSize', 11);
    title('Rx Power vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    box on;
end

subplot(1,4,4);
legend('Location', 'best', 'FontSize', 9);

saveas(fig_perf, 'Performance_vs_Distance.png');
fprintf("Created: Performance_vs_Distance.png\n");

%% ===== PART 6: TDD Configuration 비교 시각화 =====
fprintf("\n========================================================\n");
fprintf("PART 6: TDD Configuration Comparison Visualization\n");
fprintf("========================================================\n");

fig_tdd = figure('Name', 'TDD Configuration Comparison', ...
    'Position', [250 250 1200 500], 'Color', 'w', 'Visible', 'off');

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    data_f = results_tdd(results_tdd.Frequency_GHz == fc/1e9, :);
    
    % string 타입으로 처리
    config_names = unique(data_f.TDD_Config, 'stable');
    avg_dl = zeros(length(config_names), 1);
    avg_ul = zeros(length(config_names), 1);
    
    for cfg_idx = 1:length(config_names)
        cfg_name = config_names(cfg_idx);
        data_cfg = data_f(data_f.TDD_Config == cfg_name, :);
        avg_dl(cfg_idx) = mean(data_cfg.Throughput_DL_Mbps, 'omitnan');
        avg_ul(cfg_idx) = mean(data_cfg.Throughput_UL_Mbps, 'omitnan');
    end
    
    subplot(1, 2, fIdx);
    x = 1:length(config_names);
    width = 0.35;
    
    bar(x - width/2, avg_dl, width, 'FaceColor', [0.2 0.4 0.8], ...
        'EdgeColor', 'k', 'DisplayName', 'Downlink');
    hold on;
    bar(x + width/2, avg_ul, width, 'FaceColor', [0.8 0.4 0.2], ...
        'EdgeColor', 'k', 'DisplayName', 'Uplink');
    
    xlabel('TDD Configuration', 'FontSize', 11);
    ylabel('Avg Throughput (Mbps)', 'FontSize', 11);
    title(sprintf('%.1f GHz (at %dm)', fc/1e9, representative_distance), ...
        'FontSize', 12, 'FontWeight', 'normal');
    xticks(x);
    xticklabels(strrep(config_names, '_', ' '));
    xtickangle(15);
    legend('Location', 'best', 'FontSize', 9);
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    box on;
    hold off;
end

saveas(fig_tdd, 'TDD_Configuration_Comparison.png');
fprintf("Created: TDD_Configuration_Comparison.png\n");

%% ===== PART 7: 모든 Figure 표시 =====
fprintf("\n========================================================\n");
fprintf("Displaying All Figures\n");
fprintf("========================================================\n");

set(fig1, 'Visible', 'on');
set(fig_perf, 'Visible', 'on');
set(fig_tdd, 'Visible', 'on');

for i = 1:length(heatmap_figs)
    if ~isempty(heatmap_figs{i}) && isvalid(heatmap_figs{i})
        set(heatmap_figs{i}, 'Visible', 'on');
    end
end

fprintf("  All figures displayed!\n");

%% ===== 최종 요약 =====
fprintf("\n========================================================\n");
fprintf("Analysis Complete\n");
fprintf("========================================================\n");
fprintf("\nGenerated Files:\n");
fprintf("  Data:\n");
fprintf("    - %s\n", outCSV_ue_coordinates);
fprintf("    - %s\n", outCSV_points);
fprintf("    - %s\n", outCSV_heatmap);
fprintf("    - %s\n", outCSV_coverage);
fprintf("    - %s (NEW!)\n", outCSV_tdd_comparison);
fprintf("    - %s (NEW!)\n", outCSV_tdd_distance);
fprintf("\n  Figures:\n");
fprintf("    - UE_Deployment_Pattern.png\n");
fprintf("    - SNR_Heatmap_*.png\n");
fprintf("    - DL_Throughput_*.png (NEW!)\n");
fprintf("    - UL_Throughput_*.png (NEW!)\n");
fprintf("    - Performance_vs_Distance.png\n");
fprintf("    - TDD_Configuration_Comparison.png (NEW!)\n");
fprintf("\n========================================================\n");
fprintf("Key Features:\n");
fprintf("  ✓ TDD Configuration support (4 types)\n");
fprintf("  ✓ Separate DL/UL Throughput calculation\n");
fprintf("  ✓ Effective Bandwidth computation\n");
fprintf("  ✓ TDD comparison analysis\n");
fprintf("  ✓ Distance-based TDD performance\n");
fprintf("  ✓ Fixed TDD_Config table errors\n");
fprintf("========================================================\n");