%% FR1 vs FR2 분석: 실제 좌표 기반 UE 배치 (심플 스타일)
% 목적: 
%   1) BS 중심 동적 히트맵 생성
%   2) 실제 위도/경도 좌표로 UE 배치 및 시각화
%   3) Siteviewer에 모든 UE 명확하게 표시
%   4) 커버리지 통계 및 최적화 분석

clear; close all; clc;

%% ----- 사용자 설정 -----
% BS 설정
bsPosition = [37.455715, 127.133562]; % lat, lon (기지국)
bsAntennaSize = [4 4];
bsArrayOrientation = [90 0].';

% 송신 전력 설정 (dBm)
Pt_dBm = 30;

% 히트맵 설정
heatmap_radius_m = 300;  % BS로부터의 반경 (미터)
grid_resolution = 50;    % 각 차원의 그리드 포인트 수 (증가: 더 조밀)

% UE 원형 배치 설정
ue_distances = [15, 30, 45, 60, 75, 90];  % BS로부터의 거리 (미터)
ue_per_circle = 10;  % 각 원당 UE 개수

% UE 안테나 파라미터
ueAntSize = [2 2];
ueArrayOrientation = [-30 45].';

% 반사 개수
reflectionsOrder = 1;

% 실험 주파수 및 대역폭
freqs = [4.7e9, 28e9];       % FR1, FR2
bws   = [100e6, 400e6];      % 대역폭

% SNR 임계값
SNR_thresholds = [0, 5, 10, 15, 20];

% OFDM 설정
SCS = 15; NRB = 52;

% 출력 파일명
outCSV_points = "results_FR1_FR2_points.csv";
outCSV_heatmap = "results_FR1_FR2_heatmap.csv";
outCSV_coverage = "results_FR1_FR2_coverage_stats.csv";
outCSV_bs_optimization = "results_BS_optimization.csv";
outCSV_degradation = "results_FR2_degradation_analysis.csv";
outCSV_ue_coordinates = "ue_coordinates.csv";

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
fprintf("    FR1 vs FR2 Coverage Analysis\n");
fprintf("========================================================\n");

%% ----- UE 좌표 생성 -----
fprintf("\nSTEP 1: UE Coordinate Generation\n");
fprintf("  BS Position: (%.6f, %.6f)\n", bsPosition(1), bsPosition(2));
fprintf("  Distances: %s m\n", mat2str(ue_distances));
fprintf("  UE per circle: %d\n", ue_per_circle);
fprintf("  Total UE: %d\n", length(ue_distances) * ue_per_circle);

uePoints = [];
ue_info = table();
point_idx = 0;

for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    for angle_idx = 1:ue_per_circle
        point_idx = point_idx + 1;
        bearing_deg = (angle_idx - 1) * (360 / ue_per_circle);
        [ue_lat, ue_lon] = offset_position(bsPosition(1), bsPosition(2), dist, bearing_deg);
        actual_distance = latlon_to_meters(bsPosition(1), bsPosition(2), ue_lat, ue_lon);
        distance_error = abs(actual_distance - dist);
        
        uePoints = [uePoints; ue_lat, ue_lon]; %#ok<AGROW>
        
        ue_info_row = struct('UE_ID', point_idx, 'Distance_m', dist, ...
            'Bearing_deg', bearing_deg, 'Latitude', ue_lat, 'Longitude', ue_lon, ...
            'Actual_Distance_m', actual_distance, 'Distance_Error_m', distance_error);
        ue_info = [ue_info; struct2table(ue_info_row)]; %#ok<AGROW>
    end
end

fprintf("  Generated %d UE coordinates\n", size(uePoints, 1));
fprintf("  Average distance error: %.3f m\n", mean(ue_info.Distance_Error_m));
writetable(ue_info, outCSV_ue_coordinates);

%% ----- UE 배치 패턴 시각화 -----
fprintf("\nSTEP 2: UE Deployment Visualization\n");

figure('Name', 'UE Deployment Pattern', 'Position', [100 100 1000 900], 'Color', 'w');

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
        'DisplayName', sprintf('%dm', dist));
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

saveas(gcf, 'UE_Deployment_Pattern.png');
fprintf("  Saved: UE_Deployment_Pattern.png\n");

%% ----- Siteviewer 초기화 -----
fprintf("\nSTEP 3: Siteviewer Initialization\n");

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
bs_optimization_results = table();
degradation_analysis = table();

lat_grid = linspace(lat_range(1), lat_range(2), grid_resolution);
lon_grid = linspace(lon_range(1), lon_range(2), grid_resolution);
[LON_GRID, LAT_GRID] = meshgrid(lon_grid, lat_grid);

%% ===== PART 1: UE 포인트 분석 =====
fprintf("\n========================================================\n");
fprintf("PART 1: UE Point Analysis (Ray Tracing)\n");
fprintf("========================================================\n");

rowIdx = 0;

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    fprintf("\nFrequency: %.3f GHz (BW = %.1f MHz)\n", fc/1e9, bw/1e6);
    
    bsSite.TransmitterFrequency = fc;
    lambda = c / fc;
    
    bsArray = phased.NRRectangularPanelArray('Size',[bsAntennaSize(1:2) 1 1], ...
        'Spacing',[0.5*lambda*[1 1] 1 1]);
    bsArray.ElementSet = {phased.NRAntennaElement};
    
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
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
                'LOS', false, 'numPaths', 0, 'Pr_dBm', NaN, ...
                'Noise_dBm', NaN, 'SNR_dB', NaN, 'Throughput_bps', NaN, ...
                'delaySpread_s', NaN);
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
        
        kB = 1.38064852e-23; T = 290;
        Noise_W = kB * T * bw;
        Noise_dBm = 10*log10(Noise_W) + 30;
        
        SNR_dB = Pr_dBm - Noise_dBm;
        SNR_lin = 10^(SNR_dB/10);
        throughput_bps = bw * log2(1 + SNR_lin);
        
        P_sum = sum(pathGains_lin);
        if P_sum > 0
            tau_mean = sum(pathDelays .* pathGains_lin) / P_sum;
            tau_rms = sqrt( sum( ((pathDelays - tau_mean).^2) .* pathGains_lin ) / P_sum );
        else
            tau_rms = NaN;
        end
        
        row = struct('fc', fc, 'UE_ID', p, 'distance_m', ue_dist, ...
            'bearing_deg', ue_angle, 'lat', lat, 'lon', lon, ...
            'LOS', isLOS, 'numPaths', numPaths, 'Pr_dBm', Pr_dBm, ...
            'Noise_dBm', Noise_dBm, 'SNR_dB', SNR_dB, ...
            'Throughput_bps', throughput_bps, 'delaySpread_s', tau_rms);
        results_points = [results_points; struct2table(row)]; %#ok<AGROW>
    end
    
    computation_time = toc;
    fprintf("Completed in %.1f seconds\n", computation_time);
end

writetable(results_points, outCSV_points);
fprintf("\nSaved: %s\n", outCSV_points);

%% ===== PART 2: 히트맵 생성 (이미지 스타일) =====
fprintf("\n========================================================\n");
fprintf("PART 2: Coverage Heatmap Generation\n");
fprintf("========================================================\n");

SNR_maps = cell(length(freqs), 1);
Pr_maps = cell(length(freqs), 1);
TP_maps = cell(length(freqs), 1);
distance_map = nan(size(LAT_GRID));

fprintf("Computing distance map...\n");
for i = 1:size(LAT_GRID,1)
    for j = 1:size(LAT_GRID,2)
        lat = LAT_GRID(i,j);
        lon = LON_GRID(i,j);
        distance_map(i,j) = latlon_to_meters(bsPosition(1), bsPosition(2), lat, lon);
    end
end

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    freq_label = sprintf('%.1f GHz', fc/1e9);
    fprintf("\nHeatmap: %s\n", freq_label);
    
    bsSite.TransmitterFrequency = fc;
    lambda = c / fc;
    
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
    SNR_map = nan(size(LAT_GRID));
    Pr_map = nan(size(LAT_GRID));
    TP_map = nan(size(LAT_GRID));
    
    kB = 1.38064852e-23; T = 290;
    Noise_W = kB * T * bw;
    Noise_dBm = 10*log10(Noise_W) + 30;
    
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
            throughput_bps_val = bw * log2(1 + SNR_lin_val);
            
            Pr_map(i,j) = Pr_dBm_val;
            SNR_map(i,j) = SNR_dB_val;
            TP_map(i,j) = throughput_bps_val / 1e6;
            
            row_hm = struct('fc', fc, 'lat', lat, 'lon', lon, ...
                'distance_m', distance_map(i,j), ...
                'Pr_dBm', Pr_dBm_val, 'SNR_dB', SNR_dB_val, ...
                'Throughput_Mbps', throughput_bps_val/1e6);
            results_heatmap = [results_heatmap; struct2table(row_hm)]; %#ok<AGROW>
        end
    end
    
    computation_time = toc;
    fprintf("Completed in %.1f seconds\n", computation_time);
    
    SNR_maps{fIdx} = SNR_map;
    Pr_maps{fIdx} = Pr_map;
    TP_maps{fIdx} = TP_map;
    
    %% SNR 히트맵 (첨부 이미지 스타일)
    figure('Name', sprintf('SNR Heatmap - %s', freq_label), ...
        'Position', [100 100 800 600], 'Color', 'w');
    
    imagesc(lon_grid, lat_grid, SNR_map);
    set(gca, 'YDir', 'normal');
    colormap(gca, 'jet');
    caxis([-10 30]);
    
    cb = colorbar;
    cb.Label.String = '';
    cb.FontSize = 10;
    cb.LineWidth = 1;
    
    xlabel('Longitude', 'FontSize', 11);
    ylabel('Latitude', 'FontSize', 11);
    title(sprintf('SNR Heatmap - %s', freq_label), 'FontSize', 12, 'FontWeight', 'normal');
    
    hold on;
    
    % BS (작은 빨간 삼각형)
    plot(bsPosition(2), bsPosition(1), '^', ...
        'MarkerSize', 10, ...
        'MarkerFaceColor', [1 0 0], ...
        'MarkerEdgeColor', 'none');
    
    % UE (작은 흰 점)
    plot(uePoints(:,2), uePoints(:,1), 'o', ...
        'MarkerSize', 3, ...
        'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', 'none');
    
    hold off;
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    axis equal tight;
    box on;
    
    saveas(gcf, sprintf('SNR_Heatmap_%s.png', strrep(freq_label, ' ', '_')), 'png');
    print(gcf, sprintf('SNR_Heatmap_%s.pdf', strrep(freq_label, ' ', '_')), '-dpdf', '-r300');
    
    %% Throughput 히트맵 (첨부 이미지 스타일)
    figure('Name', sprintf('Throughput Heatmap - %s', freq_label), ...
        'Position', [150 150 800 600], 'Color', 'w');
    
    imagesc(lon_grid, lat_grid, TP_map);
    set(gca, 'YDir', 'normal');
    colormap(gca, 'hot');
    
    cb = colorbar;
    cb.Label.String = '';
    cb.FontSize = 10;
    cb.LineWidth = 1;
    
    xlabel('Longitude', 'FontSize', 11);
    ylabel('Latitude', 'FontSize', 11);
    title(sprintf('Throughput Heatmap - %s', freq_label), 'FontSize', 12, 'FontWeight', 'normal');
    
    hold on;
    
    % BS
    plot(bsPosition(2), bsPosition(1), '^', ...
        'MarkerSize', 10, ...
        'MarkerFaceColor', [1 0 0], ...
        'MarkerEdgeColor', 'none');
    
    % UE
    plot(uePoints(:,2), uePoints(:,1), 'o', ...
        'MarkerSize', 3, ...
        'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', 'none');
    
    hold off;
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    axis equal tight;
    box on;
    
    saveas(gcf, sprintf('Throughput_Heatmap_%s.png', strrep(freq_label, ' ', '_')), 'png');
    print(gcf, sprintf('Throughput_Heatmap_%s.pdf', strrep(freq_label, ' ', '_')), '-dpdf', '-r300');
    
    %% Received Power 히트맵 (첨부 이미지 스타일)
    figure('Name', sprintf('Received Power Heatmap - %s', freq_label), ...
        'Position', [200 200 800 600], 'Color', 'w');
    
    imagesc(lon_grid, lat_grid, Pr_map);
    set(gca, 'YDir', 'normal');
    colormap(gca, 'parula');
    
    cb = colorbar;
    cb.Label.String = '';
    cb.FontSize = 10;
    cb.LineWidth = 1;
    
    xlabel('Longitude', 'FontSize', 11);
    ylabel('Latitude', 'FontSize', 11);
    title(sprintf('Received Power Heatmap - %s', freq_label), 'FontSize', 12, 'FontWeight', 'normal');
    
    hold on;
    
    % BS
    plot(bsPosition(2), bsPosition(1), '^', ...
        'MarkerSize', 10, ...
        'MarkerFaceColor', [1 0 0], ...
        'MarkerEdgeColor', 'none');
    
    % UE
    plot(uePoints(:,2), uePoints(:,1), 'o', ...
        'MarkerSize', 3, ...
        'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', 'none');
    
    hold off;
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    axis equal tight;
    box on;
    
    saveas(gcf, sprintf('RxPower_Heatmap_%s.png', strrep(freq_label, ' ', '_')), 'png');
    print(gcf, sprintf('RxPower_Heatmap_%s.pdf', strrep(freq_label, ' ', '_')), '-dpdf', '-r300');
    
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

%% ===== PART 3: 거리별 성능 분석 =====
fprintf("\n========================================================\n");
fprintf("PART 3: Performance vs Distance\n");
fprintf("========================================================\n");

figure('Name','Performance vs Distance', 'Position', [100 100 1200 400], 'Color', 'w');

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    data_f = results_points(results_points.fc == fc, :);
    
    avg_snr = zeros(length(ue_distances), 1);
    avg_tp = zeros(length(ue_distances), 1);
    avg_pr = zeros(length(ue_distances), 1);
    
    for d_idx = 1:length(ue_distances)
        dist = ue_distances(d_idx);
        data_dist = data_f(data_f.distance_m == dist, :);
        avg_snr(d_idx) = mean(data_dist.SNR_dB, 'omitnan');
        avg_tp(d_idx) = mean(data_dist.Throughput_bps / 1e6, 'omitnan');
        avg_pr(d_idx) = mean(data_dist.Pr_dBm, 'omitnan');
    end
    
    % SNR
    subplot(1,3,1);
    if fIdx == 1
        plot(ue_distances, avg_snr, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(ue_distances, avg_snr, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance from BS (m)', 'FontSize', 11);
    ylabel('Average SNR (dB)', 'FontSize', 11);
    title('SNR vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.3);
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    box on;
    
    % Throughput
    subplot(1,3,2);
    if fIdx == 1
        plot(ue_distances, avg_tp, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(ue_distances, avg_tp, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance from BS (m)', 'FontSize', 11);
    ylabel('Average Throughput (Mbps)', 'FontSize', 11);
    title('Throughput vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.3);
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    box on;
    
    % Rx Power
    subplot(1,3,3);
    if fIdx == 1
        plot(ue_distances, avg_pr, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    else
        plot(ue_distances, avg_pr, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'DisplayName', sprintf('%.1f GHz', fc/1e9));
    end
    hold on;
    xlabel('Distance from BS (m)', 'FontSize', 11);
    ylabel('Average Rx Power (dBm)', 'FontSize', 11);
    title('Received Power vs Distance', 'FontSize', 12, 'FontWeight', 'normal');
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.3);
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    box on;
end

subplot(1,3,3);
legend('Location', 'best', 'FontSize', 9, 'Box', 'on', 'LineWidth', 1);

saveas(gcf, 'Performance_vs_Distance.png', 'png');
print(gcf, 'Performance_vs_Distance.pdf', '-dpdf', '-r300');

%% ===== PART 4: 커버리지 비교 =====
fprintf("\n========================================================\n");
fprintf("PART 4: Coverage Comparison\n");
fprintf("========================================================\n");

figure('Name', 'Coverage Comparison', 'Position', [200 200 900 400], 'Color', 'w');

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    stats_f = coverage_stats(coverage_stats.fc == fc, :);
    
    subplot(1, 2, fIdx);
    
    if fIdx == 1
        bar(stats_f.SNR_threshold_dB, stats_f.coverage_ratio_percent, ...
            'FaceColor', [0 0.4470 0.7410], 'EdgeColor', 'k', 'LineWidth', 1);
    else
        bar(stats_f.SNR_threshold_dB, stats_f.coverage_ratio_percent, ...
            'FaceColor', [0.8500 0.3250 0.0980], 'EdgeColor', 'k', 'LineWidth', 1);
    end
    
    xlabel('SNR Threshold (dB)', 'FontSize', 11);
    ylabel('Coverage Ratio (%)', 'FontSize', 11);
    title(sprintf('%.1f GHz', fc/1e9), 'FontSize', 12, 'FontWeight', 'normal');
    ylim([0 100]);
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.3);
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    box on;
end

saveas(gcf, 'Coverage_Comparison.png', 'png');
print(gcf, 'Coverage_Comparison.pdf', '-dpdf', '-r300');

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
fprintf("\n  Figures:\n");
fprintf("    - UE_Deployment_Pattern.png\n");
fprintf("    - SNR_Heatmap_*.png/pdf\n");
fprintf("    - Throughput_Heatmap_*.png/pdf\n");
fprintf("    - RxPower_Heatmap_*.png/pdf\n");
fprintf("    - Performance_vs_Distance.png/pdf\n");
fprintf("    - Coverage_Comparison.png/pdf\n");
fprintf("\n========================================================\n");