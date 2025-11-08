%% FR1 vs FR2 고급 분석: 기지국 최적화 및 군사용 통신 요구사항 분석
% 파일명: FR1_FR2_Advanced_Analysis.m
% 목적: 
%   1) 전체 영역에 대한 커버리지 히트맵 생성 (SNR, Pr, Throughput)
%   2) 대표 포인트 6개에서 상세 분석
%   3) 커버리지 통계 (커버리지율, 사각지대 등)
%   4) FR2에서 FR1과 동일한 커버리지를 위한 추가 기지국 수 계산
%   5) FR2 거리별 성능 저하 분석
%   6) 군사용 통신 요구사항 충족을 위한 최적화 방안 도출

clear; close all; clc;

%% ----- 사용자 설정 -----
% BS 설정
bsPosition = [37.4536, 127.1369]; % lat, lon (기지국)
bsAntennaSize = [4 4];
bsArrayOrientation = [90 0].';

% 송신 전력 설정 (dBm)
Pt_dBm = 23;

% 대표 포인트 6개 (상세 분석용)
uePoints = [
    37.45550 127.13380;  % point 1
    37.45490 127.13400;  % point 2
    37.45470 127.13500;  % point 3
    37.45510 127.13520;  % point 4
    37.45530 127.13450;  % point 5
    37.45485 127.13350   % point 6
];

% 히트맵 그리드 설정 (위도/경도 범위 및 해상도)
lat_range = [37.4530, 37.4560];  % 위도 범위 (약 330m)
lon_range = [127.1320, 127.1380]; % 경도 범위 (약 480m)
grid_resolution = 30;  % 각 차원의 그리드 포인트 수 (30x30 = 900 포인트)

% UE 안테나 파라미터
ueAntSize = [2 2];
ueArrayOrientation = [-30 45].';

% 반사 개수
reflectionsOrder = 1;

% 실험 주파수 및 대역폭
freqs = [4.7e9, 28e9];       % FR1, FR2
bws   = [100e6, 400e6];      % 대역폭

% SNR 임계값 (커버리지 판단 기준, dB)
SNR_thresholds = [0, 5, 10, 15, 20]; % 다양한 임계값

% ===== 군사용 통신 요구사항 =====
MILITARY_REQUIREMENTS = struct();
MILITARY_REQUIREMENTS.min_SNR_dB = 15;           % 최소 SNR (dB)
MILITARY_REQUIREMENTS.min_throughput_Mbps = 50;  % 최소 처리량 (Mbps)
MILITARY_REQUIREMENTS.min_reliability = 99.5;    % 최소 신뢰도 (%)
MILITARY_REQUIREMENTS.max_latency_ms = 10;       % 최대 지연시간 (ms)
MILITARY_REQUIREMENTS.coverage_target = 95;      % 목표 커버리지율 (%)

% OFDM 설정
SCS = 15; NRB = 52;

% 출력 파일명
outCSV_points = "results_FR1_FR2_points.csv";
outCSV_heatmap = "results_FR1_FR2_heatmap.csv";
outCSV_coverage = "results_FR1_FR2_coverage_stats.csv";
outCSV_bs_optimization = "results_BS_optimization.csv";
outCSV_degradation = "results_FR2_degradation_analysis.csv";
outCSV_military = "results_military_requirements.csv";

%% ----- 준비 -----
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

% BS site 생성
fc_init = freqs(1);
bsSite = txsite("Name","Base station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2),...
    "AntennaAngle",bsArrayOrientation(1:2),...
    "AntennaHeight",4,...
    "TransmitterFrequency",fc_init);

show(bsSite);

c = physconst('LightSpeed');
ofdmInfo = nrOFDMInfo(NRB,SCS);

% 결과 저장 테이블
results_points = table();
results_heatmap = table();
coverage_stats = table();
bs_optimization_results = table();
degradation_analysis = table();
military_analysis = table();

% 히트맵 그리드 생성
lat_grid = linspace(lat_range(1), lat_range(2), grid_resolution);
lon_grid = linspace(lon_range(1), lon_range(2), grid_resolution);
[LAT_GRID, LON_GRID] = meshgrid(lat_grid, lon_grid);

%% ===== PART 1: 대표 포인트 6개 상세 분석 =====
fprintf("\n========== PART 1: 대표 포인트 분석 ==========\n");
rowIdx = 0;

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    fprintf("\n=== Frequency: %.3f GHz (BW = %.1f MHz) ===\n", fc/1e9, bw/1e6);
    
    bsSite.TransmitterFrequency = fc;
    lambda = c / fc;
    
    bsArray = phased.NRRectangularPanelArray('Size',[bsAntennaSize(1:2) 1 1], ...
        'Spacing',[0.5*lambda*[1 1] 1 1]);
    bsArray.ElementSet = {phased.NRAntennaElement};
    
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
    for p = 1:size(uePoints,1)
        rowIdx = rowIdx + 1;
        lat = uePoints(p,1); lon = uePoints(p,2);
        fprintf("Point %d: (%.6f, %.6f)\n", p, lat, lon);
        
        rx = rxsite("Name", sprintf("UE_p%d_f%d", p, fIdx), ...
            "Latitude", lat, "Longitude", lon, ...
            "AntennaHeight", 1, ...
            "AntennaAngle", ueArrayOrientation(1:2));
        show(rx);
        
        rays = raytrace(bsSite, rx, pm, "Type","pathloss");
        
        if isempty(rays) || isempty(rays{1})
            warning("Point %d, fIdx %d: raytrace 결과 없음", p, fIdx);
            row = struct('fc', fc, 'point', p, 'lat', lat, 'lon', lon, ...
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
        
        row = struct('fc', fc, 'point', p, 'lat', lat, 'lon', lon, ...
            'LOS', isLOS, 'numPaths', numPaths, 'Pr_dBm', Pr_dBm, ...
            'Noise_dBm', Noise_dBm, 'SNR_dB', SNR_dB, ...
            'Throughput_bps', throughput_bps, 'delaySpread_s', tau_rms);
        results_points = [results_points; struct2table(row)]; %#ok<AGROW>
    end
end

writetable(results_points, outCSV_points);
fprintf("\n대표 포인트 결과가 %s 에 저장되었습니다.\n", outCSV_points);

%% ===== PART 2: 히트맵 생성 =====
fprintf("\n========== PART 2: 커버리지 히트맵 생성 ==========\n");

% 각 주파수별 히트맵 데이터 저장
SNR_maps = cell(length(freqs), 1);
Pr_maps = cell(length(freqs), 1);
TP_maps = cell(length(freqs), 1);
distance_map = nan(size(LAT_GRID));

% 거리 맵 계산 (한 번만)
for i = 1:size(LAT_GRID,1)
    for j = 1:size(LAT_GRID,2)
        lat = LAT_GRID(i,j);
        lon = LON_GRID(i,j);
        distance_map(i,j) = distance(bsPosition(1), bsPosition(2), lat, lon) * 1000; % km to m
    end
end

for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    fprintf("\n=== Heatmap for %.3f GHz ===\n", fc/1e9);
    
    bsSite.TransmitterFrequency = fc;
    lambda = c / fc;
    
    pm = propagationModel("raytracing","Method","sbr", ...
        "MaxNumReflections", reflectionsOrder, "MaxNumDiffractions",0);
    
    % 히트맵 데이터 저장용 행렬
    SNR_map = nan(size(LAT_GRID));
    Pr_map = nan(size(LAT_GRID));
    TP_map = nan(size(LAT_GRID));
    
    % 노이즈 전력 계산 (주파수별)
    kB = 1.38064852e-23; T = 290;
    Noise_W = kB * T * bw;
    Noise_dBm = 10*log10(Noise_W) + 30;
    
    total_points = numel(LAT_GRID);
    fprintf("총 %d 개 그리드 포인트 계산 중...\n", total_points);
    
    for i = 1:size(LAT_GRID,1)
        if mod(i,5)==0
            fprintf("  진행: %d/%d 행\n", i, size(LAT_GRID,1));
        end
        for j = 1:size(LAT_GRID,2)
            lat = LAT_GRID(i,j);
            lon = LON_GRID(i,j);
            
            % 임시 rxsite 생성 (표시는 하지 않음)
            rx_temp = rxsite("Latitude", lat, "Longitude", lon, ...
                "AntennaHeight", 1, ...
                "AntennaAngle", ueArrayOrientation(1:2));
            
            rays = raytrace(bsSite, rx_temp, pm, "Type","pathloss");
            
            if isempty(rays) || isempty(rays{1})
                % 경로 없음 - NaN 유지
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
            
            % 저장
            Pr_map(i,j) = Pr_dBm_val;
            SNR_map(i,j) = SNR_dB_val;
            TP_map(i,j) = throughput_bps_val / 1e6; % Mbps
            
            % 테이블에도 저장
            row_hm = struct('fc', fc, 'lat', lat, 'lon', lon, ...
                'distance_m', distance_map(i,j), ...
                'Pr_dBm', Pr_dBm_val, 'SNR_dB', SNR_dB_val, ...
                'Throughput_Mbps', throughput_bps_val/1e6);
            results_heatmap = [results_heatmap; struct2table(row_hm)]; %#ok<AGROW>
        end
    end
    
    % 히트맵 저장
    SNR_maps{fIdx} = SNR_map;
    Pr_maps{fIdx} = Pr_map;
    TP_maps{fIdx} = TP_map;
    
    % 히트맵 플롯
    freq_label = sprintf('%.1f GHz', fc/1e9);
    
    % SNR 히트맵
    figure('Name', sprintf('SNR Heatmap - %s', freq_label));
    imagesc(lon_grid, lat_grid, SNR_map);
    set(gca, 'YDir', 'normal');
    colorbar; xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('SNR Heatmap - %s', freq_label));
    caxis([-10 30]); % SNR 범위 조정
    colormap('jet');
    hold on;
    plot(bsPosition(2), bsPosition(1), 'r^', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    plot(uePoints(:,2), uePoints(:,1), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    hold off;
    saveas(gcf, sprintf('Heatmap_SNR_%.1fGHz.png', fc/1e9));
    
    % Throughput 히트맵
    figure('Name', sprintf('Throughput Heatmap - %s', freq_label));
    imagesc(lon_grid, lat_grid, TP_map);
    set(gca, 'YDir', 'normal');
    colorbar; xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('Throughput Heatmap (Mbps) - %s', freq_label));
    colormap('hot');
    hold on;
    plot(bsPosition(2), bsPosition(1), 'r^', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    plot(uePoints(:,2), uePoints(:,1), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    hold off;
    saveas(gcf, sprintf('Heatmap_Throughput_%.1fGHz.png', fc/1e9));
    
    % 수신 전력 히트맵
    figure('Name', sprintf('Received Power Heatmap - %s', freq_label));
    imagesc(lon_grid, lat_grid, Pr_map);
    set(gca, 'YDir', 'normal');
    colorbar; xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('Received Power (dBm) - %s', freq_label));
    colormap('parula');
    hold on;
    plot(bsPosition(2), bsPosition(1), 'r^', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    plot(uePoints(:,2), uePoints(:,1), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    hold off;
    saveas(gcf, sprintf('Heatmap_RxPower_%.1fGHz.png', fc/1e9));
    
    % 커버리지 통계 계산
    for thr = SNR_thresholds
        valid_points = ~isnan(SNR_map);
        total_valid = sum(valid_points(:));
        covered = sum(SNR_map(valid_points) >= thr);
        coverage_ratio = covered / total_valid * 100; % 퍼센트
        
        stat_row = struct('fc', fc, 'SNR_threshold_dB', thr, ...
            'total_points', total_valid, 'covered_points', covered, ...
            'coverage_ratio_percent', coverage_ratio);
        coverage_stats = [coverage_stats; struct2table(stat_row)]; %#ok<AGROW>
        
        fprintf("  SNR >= %d dB: 커버리지율 = %.2f%% (%d/%d)\n", ...
            thr, coverage_ratio, covered, total_valid);
    end
end

writetable(results_heatmap, outCSV_heatmap);
writetable(coverage_stats, outCSV_coverage);
fprintf("\n히트맵 데이터가 %s 에 저장되었습니다.\n", outCSV_heatmap);
fprintf("커버리지 통계가 %s 에 저장되었습니다.\n", outCSV_coverage);

%% ===== PART 3: 대표 포인트 비교 플롯 (기존) =====
fprintf("\n========== PART 3: 대표 포인트 비교 플롯 ==========\n");

uniquePoints = unique(results_points.point);
nPoints = length(uniquePoints);

% SNR bar
figure('Name','SNR Comparison (per point)');
SNR_mat = nan(nPoints, length(freqs));
for i = 1:nPoints
    for fIdx = 1:length(freqs)
        row = results_points(results_points.point==i & results_points.fc==freqs(fIdx), :);
        if ~isempty(row)
            SNR_mat(i,fIdx) = row.SNR_dB;
        end
    end
end
bar(SNR_mat); grid on;
xticks(1:nPoints); xticklabels(arrayfun(@(x)sprintf('P%d',x),1:nPoints,'UniformOutput',false));
xlabel('Point'); ylabel('SNR (dB)');
legend(arrayfun(@(f)sprintf('%.1f GHz',f/1e9),freqs,'UniformOutput',false),'Location','best');
title('SNR: FR1 vs FR2 (per point)');
saveas(gcf,'SNR_bar.png');

% Throughput bar
figure('Name','Throughput Comparison (per point)');
TP_mat = nan(nPoints, length(freqs));
for i = 1:nPoints
    for fIdx = 1:length(freqs)
        row = results_points(results_points.point==i & results_points.fc==freqs(fIdx), :);
        if ~isempty(row)
            TP_mat(i,fIdx) = row.Throughput_bps / 1e6;
        end
    end
end
bar(TP_mat); grid on;
xticks(1:nPoints); xticklabels(arrayfun(@(x)sprintf('P%d',x),1:nPoints,'UniformOutput',false));
xlabel('Point'); ylabel('Throughput (Mbps)');
legend(arrayfun(@(f)sprintf('%.1f GHz',f/1e9),freqs,'UniformOutput',false),'Location','best');
title('Throughput: FR1 vs FR2 (per point)');
saveas(gcf,'Throughput_bar.png');

% Delay spread bar
figure('Name','Delay Spread Comparison');
DS_mat = nan(nPoints, length(freqs));
for i = 1:nPoints
    for fIdx = 1:length(freqs)
        row = results_points(results_points.point==i & results_points.fc==freqs(fIdx), :);
        if ~isempty(row)
            DS_mat(i,fIdx) = row.delaySpread_s*1e9;
        end
    end
end
bar(DS_mat); grid on;
xticks(1:nPoints); xticklabels(arrayfun(@(x)sprintf('P%d',x),1:nPoints,'UniformOutput',false));
xlabel('Point'); ylabel('RMS Delay Spread (ns)');
legend(arrayfun(@(f)sprintf('%.1f GHz',f/1e9),freqs,'UniformOutput',false),'Location','best');
title('RMS Delay Spread: FR1 vs FR2 (per point)');
saveas(gcf,'DelaySpread_bar.png');

%% ===== PART 4: FR1 vs FR2 커버리지 비교 플롯 =====
fprintf("\n========== PART 4: FR1 vs FR2 커버리지 비교 =====\n");

figure('Name', 'Coverage Comparison: FR1 vs FR2');
for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    stats_f = coverage_stats(coverage_stats.fc == fc, :);
    
    subplot(1, length(freqs), fIdx);
    bar(stats_f.SNR_threshold_dB, stats_f.coverage_ratio_percent);
    xlabel('SNR Threshold (dB)');
    ylabel('Coverage Ratio (%)');
    title(sprintf('%.1f GHz', fc/1e9));
    ylim([0 100]);
    grid on;
end
saveas(gcf, 'Coverage_Comparison.png');

%% ===== PART 5: 추가 기지국 수 계산 (NEW) =====
fprintf("\n========== PART 5: FR2 추가 기지국 수 계산 ==========\n");

% FR1과 FR2의 커버리지 비교
SNR_map_FR1 = SNR_maps{1};
SNR_map_FR2 = SNR_maps{2};

% 다양한 SNR 임계값에 대해 분석
for thr_idx = 1:length(SNR_thresholds)
    thr = SNR_thresholds(thr_idx);
    
    % FR1 커버리지
    FR1_covered = ~isnan(SNR_map_FR1) & (SNR_map_FR1 >= thr);
    FR1_coverage_ratio = sum(FR1_covered(:)) / sum(~isnan(SNR_map_FR1(:))) * 100;
    FR1_coverage_area_m2 = sum(FR1_covered(:)) * (distance(lat_range(1), lon_range(1), lat_range(2), lon_range(2)) * 1000)^2 / numel(LAT_GRID);
    
    % FR2 커버리지
    FR2_covered = ~isnan(SNR_map_FR2) & (SNR_map_FR2 >= thr);
    FR2_coverage_ratio = sum(FR2_covered(:)) / sum(~isnan(SNR_map_FR2(:))) * 100;
    FR2_coverage_area_m2 = sum(FR2_covered(:)) * (distance(lat_range(1), lon_range(1), lat_range(2), lon_range(2)) * 1000)^2 / numel(LAT_GRID);
    
    % 커버리지 비율 차이
    coverage_gap = FR1_coverage_ratio - FR2_coverage_ratio;
    
    % 필요한 추가 기지국 수 추정
    % 방법 1: 단순 면적 비율
    if FR2_coverage_area_m2 > 0
        additional_BS_area_based = ceil(FR1_coverage_area_m2 / FR2_coverage_area_m2) - 1;
    else
        additional_BS_area_based = Inf;
    end
    
    % 방법 2: 커버리지 갭 기반
    if FR2_coverage_ratio > 0
        additional_BS_gap_based = ceil(FR1_coverage_ratio / FR2_coverage_ratio) - 1;
    else
        additional_BS_gap_based = Inf;
    end
    
    % 방법 3: 육각형 셀 모델 (이론적)
    % FR2의 평균 커버리지 반경 추정
    FR2_distances = distance_map(FR2_covered);
    if ~isempty(FR2_distances)
        FR2_avg_radius_m = mean(FR2_distances);
        FR2_cell_area_m2 = 2.598 * FR2_avg_radius_m^2; % 육각형 면적
        
        FR1_distances = distance_map(FR1_covered);
        FR1_avg_radius_m = mean(FR1_distances);
        FR1_cell_area_m2 = 2.598 * FR1_avg_radius_m^2;
        
        additional_BS_hexagonal = ceil(FR1_cell_area_m2 / FR2_cell_area_m2) - 1;
        
        % 실제 영역 크기 고려
        total_area_m2 = (distance(lat_range(1), lon_range(1), lat_range(2), lon_range(2)) * 1000)^2;
        total_BS_needed_FR2 = ceil(total_area_m2 / FR2_cell_area_m2);
        total_BS_needed_FR1 = ceil(total_area_m2 / FR1_cell_area_m2);
    else
        additional_BS_hexagonal = Inf;
        FR2_avg_radius_m = NaN;
        FR1_avg_radius_m = NaN;
        total_BS_needed_FR2 = Inf;
        total_BS_needed_FR1 = 1;
    end
    
    % 결과 저장
    bs_opt_row = struct(...
        'SNR_threshold_dB', thr, ...
        'FR1_coverage_percent', FR1_coverage_ratio, ...
        'FR2_coverage_percent', FR2_coverage_ratio, ...
        'coverage_gap_percent', coverage_gap, ...
        'FR1_avg_radius_m', FR1_avg_radius_m, ...
        'FR2_avg_radius_m', FR2_avg_radius_m, ...
        'additional_BS_area_method', additional_BS_area_based, ...
        'additional_BS_gap_method', additional_BS_gap_based, ...
        'additional_BS_hexagonal_method', additional_BS_hexagonal, ...
        'total_BS_needed_FR1', total_BS_needed_FR1, ...
        'total_BS_needed_FR2', total_BS_needed_FR2, ...
        'recommended_additional_BS', max([additional_BS_area_based, additional_BS_gap_based, additional_BS_hexagonal]));
    
    bs_optimization_results = [bs_optimization_results; struct2table(bs_opt_row)]; %#ok<AGROW>
    
    fprintf("\n--- SNR >= %d dB ---\n", thr);
    fprintf("FR1 커버리지: %.2f%% (평균 반경: %.1fm)\n", FR1_coverage_ratio, FR1_avg_radius_m);
    fprintf("FR2 커버리지: %.2f%% (평균 반경: %.1fm)\n", FR2_coverage_ratio, FR2_avg_radius_m);
    fprintf("커버리지 갭: %.2f%%\n", coverage_gap);
    fprintf("추가 필요 BS 수:\n");
    fprintf("  - 면적 기반: %d개\n", additional_BS_area_based);
    fprintf("  - 갭 기반: %d개\n", additional_BS_gap_based);
    fprintf("  - 육각형 모델: %d개\n", additional_BS_hexagonal);
    fprintf("  - 권장: %d개\n", max([additional_BS_area_based, additional_BS_gap_based, additional_BS_hexagonal]));
    fprintf("전체 영역 커버를 위한 총 BS 수:\n");
    fprintf("  - FR1: %d개\n", total_BS_needed_FR1);
    fprintf("  - FR2: %d개\n", total_BS_needed_FR2);
end

writetable(bs_optimization_results, outCSV_bs_optimization);
fprintf("\n기지국 최적화 결과가 %s 에 저장되었습니다.\n", outCSV_bs_optimization);

% 추가 기지국 수 시각화
figure('Name', 'Additional BS Requirements for FR2');
subplot(2,1,1);
bar(bs_optimization_results.SNR_threshold_dB, ...
    [bs_optimization_results.additional_BS_area_method, ...
     bs_optimization_results.additional_BS_gap_method, ...
     bs_optimization_results.additional_BS_hexagonal_method]);
xlabel('SNR Threshold (dB)');
ylabel('Number of Additional BS');
legend('Area Method', 'Gap Method', 'Hexagonal Model', 'Location', 'best');
title('FR2: Additional Base Stations Required (Different Methods)');
grid on;

subplot(2,1,2);
bar(bs_optimization_results.SNR_threshold_dB, ...
    [bs_optimization_results.total_BS_needed_FR1, ...
     bs_optimization_results.total_BS_needed_FR2]);
xlabel('SNR Threshold (dB)');
ylabel('Total Number of BS');
legend('FR1', 'FR2', 'Location', 'best');
title('Total Base Stations Required for Full Coverage');
grid on;
saveas(gcf, 'BS_Optimization_Analysis.png');

% 커버리지 반경 비교
figure('Name', 'Coverage Radius Comparison');
bar(bs_optimization_results.SNR_threshold_dB, ...
    [bs_optimization_results.FR1_avg_radius_m, ...
     bs_optimization_results.FR2_avg_radius_m]);
xlabel('SNR Threshold (dB)');
ylabel('Average Coverage Radius (m)');
legend('FR1 (4.7 GHz)', 'FR2 (28 GHz)', 'Location', 'best');
title('Average Coverage Radius: FR1 vs FR2');
grid on;
saveas(gcf, 'Coverage_Radius_Comparison.png');

%% ===== PART 6: FR2 거리별 성능 저하 분석 (NEW) =====
fprintf("\n========== PART 6: FR2 거리별 성능 저하 분석 ==========\n");

% 거리 구간 설정 (미터 단위)
distance_bins = 0:50:500; % 0m부터 500m까지 50m 간격
distance_bin_centers = (distance_bins(1:end-1) + distance_bins(2:end)) / 2;

% FR1과 FR2 데이터 추출
FR1_data = results_heatmap(results_heatmap.fc == freqs(1), :);
FR2_data = results_heatmap(results_heatmap.fc == freqs(2), :);

% 거리별 통계 계산
for bin_idx = 1:length(distance_bins)-1
    dist_min = distance_bins(bin_idx);
    dist_max = distance_bins(bin_idx+1);
    dist_center = distance_bin_centers(bin_idx);
    
    % FR1 통계
    FR1_in_bin = FR1_data(FR1_data.distance_m >= dist_min & FR1_data.distance_m < dist_max, :);
    if ~isempty(FR1_in_bin)
        FR1_mean_SNR = mean(FR1_in_bin.SNR_dB, 'omitnan');
        FR1_std_SNR = std(FR1_in_bin.SNR_dB, 'omitnan');
        FR1_mean_TP = mean(FR1_in_bin.Throughput_Mbps, 'omitnan');
        FR1_mean_Pr = mean(FR1_in_bin.Pr_dBm, 'omitnan');
        FR1_coverage_10dB = sum(FR1_in_bin.SNR_dB >= 10) / height(FR1_in_bin) * 100;
        FR1_coverage_15dB = sum(FR1_in_bin.SNR_dB >= 15) / height(FR1_in_bin) * 100;
    else
        FR1_mean_SNR = NaN; FR1_std_SNR = NaN; FR1_mean_TP = NaN;
        FR1_mean_Pr = NaN; FR1_coverage_10dB = NaN; FR1_coverage_15dB = NaN;
    end
    
    % FR2 통계
    FR2_in_bin = FR2_data(FR2_data.distance_m >= dist_min & FR2_data.distance_m < dist_max, :);
    if ~isempty(FR2_in_bin)
        FR2_mean_SNR = mean(FR2_in_bin.SNR_dB, 'omitnan');
        FR2_std_SNR = std(FR2_in_bin.SNR_dB, 'omitnan');
        FR2_mean_TP = mean(FR2_in_bin.Throughput_Mbps, 'omitnan');
        FR2_mean_Pr = mean(FR2_in_bin.Pr_dBm, 'omitnan');
        FR2_coverage_10dB = sum(FR2_in_bin.SNR_dB >= 10) / height(FR2_in_bin) * 100;
        FR2_coverage_15dB = sum(FR2_in_bin.SNR_dB >= 15) / height(FR2_in_bin) * 100;
    else
        FR2_mean_SNR = NaN; FR2_std_SNR = NaN; FR2_mean_TP = NaN;
        FR2_mean_Pr = NaN; FR2_coverage_10dB = NaN; FR2_coverage_15dB = NaN;
    end
    
    % 성능 저하 계산
    SNR_degradation_dB = FR1_mean_SNR - FR2_mean_SNR;
    TP_degradation_percent = (FR1_mean_TP - FR2_mean_TP) / FR1_mean_TP * 100;
    Pr_degradation_dB = FR1_mean_Pr - FR2_mean_Pr;
    
    % 임계 거리 판단 (FR2가 FR1 대비 10% 이상 성능 저하)
    is_critical = abs(TP_degradation_percent) > 10 || SNR_degradation_dB > 5;
    
    % 결과 저장
    degrad_row = struct(...
        'distance_min_m', dist_min, ...
        'distance_max_m', dist_max, ...
        'distance_center_m', dist_center, ...
        'FR1_mean_SNR_dB', FR1_mean_SNR, ...
        'FR1_std_SNR_dB', FR1_std_SNR, ...
        'FR1_mean_Throughput_Mbps', FR1_mean_TP, ...
        'FR1_mean_Pr_dBm', FR1_mean_Pr, ...
        'FR1_coverage_10dB_percent', FR1_coverage_10dB, ...
        'FR1_coverage_15dB_percent', FR1_coverage_15dB, ...
        'FR2_mean_SNR_dB', FR2_mean_SNR, ...
        'FR2_std_SNR_dB', FR2_std_SNR, ...
        'FR2_mean_Throughput_Mbps', FR2_mean_TP, ...
        'FR2_mean_Pr_dBm', FR2_mean_Pr, ...
        'FR2_coverage_10dB_percent', FR2_coverage_10dB, ...
        'FR2_coverage_15dB_percent', FR2_coverage_15dB, ...
        'SNR_degradation_dB', SNR_degradation_dB, ...
        'Throughput_degradation_percent', TP_degradation_percent, ...
        'Pr_degradation_dB', Pr_degradation_dB, ...
        'is_critical_degradation', is_critical);
    
    degradation_analysis = [degradation_analysis; struct2table(degrad_row)]; %#ok<AGROW>
    
    if ~isnan(SNR_degradation_dB)
        fprintf("거리 %d-%dm: SNR 저하 = %.2f dB, TP 저하 = %.2f%%, Pr 저하 = %.2f dB%s\n", ...
            dist_min, dist_max, SNR_degradation_dB, TP_degradation_percent, Pr_degradation_dB, ...
            ternary(is_critical, ' [임계]', ''));
    end
end

writetable(degradation_analysis, outCSV_degradation);
fprintf("\n성능 저하 분석 결과가 %s 에 저장되었습니다.\n", outCSV_degradation);

% 성능 저하 시각화
figure('Name', 'FR2 Performance Degradation Analysis');

% SNR vs Distance
subplot(2,2,1);
plot(degradation_analysis.distance_center_m, degradation_analysis.FR1_mean_SNR_dB, 'b-o', 'LineWidth', 2);
hold on;
plot(degradation_analysis.distance_center_m, degradation_analysis.FR2_mean_SNR_dB, 'r-s', 'LineWidth', 2);
yline(MILITARY_REQUIREMENTS.min_SNR_dB, 'k--', 'Min Required (Military)', 'LineWidth', 1.5);
hold off;
xlabel('Distance from BS (m)');
ylabel('Mean SNR (dB)');
legend('FR1', 'FR2', 'Military Min', 'Location', 'best');
title('SNR vs Distance');
grid on;

% Throughput vs Distance
subplot(2,2,2);
plot(degradation_analysis.distance_center_m, degradation_analysis.FR1_mean_Throughput_Mbps, 'b-o', 'LineWidth', 2);
hold on;
plot(degradation_analysis.distance_center_m, degradation_analysis.FR2_mean_Throughput_Mbps, 'r-s', 'LineWidth', 2);
yline(MILITARY_REQUIREMENTS.min_throughput_Mbps, 'k--', 'Min Required (Military)', 'LineWidth', 1.5);
hold off;
xlabel('Distance from BS (m)');
ylabel('Mean Throughput (Mbps)');
legend('FR1', 'FR2', 'Military Min', 'Location', 'best');
title('Throughput vs Distance');
grid on;

% SNR Degradation
subplot(2,2,3);
bar(degradation_analysis.distance_center_m, degradation_analysis.SNR_degradation_dB);
xlabel('Distance from BS (m)');
ylabel('SNR Degradation (dB)');
title('FR1 vs FR2: SNR Degradation');
grid on;

% Throughput Degradation
subplot(2,2,4);
bar(degradation_analysis.distance_center_m, degradation_analysis.Throughput_degradation_percent);
xlabel('Distance from BS (m)');
ylabel('Throughput Degradation (%)');
title('FR1 vs FR2: Throughput Degradation');
grid on;

saveas(gcf, 'FR2_Performance_Degradation.png');

% 임계 거리 식별
critical_distances = degradation_analysis(degradation_analysis.is_critical_degradation, :);
if ~isempty(critical_distances)
    fprintf("\n*** 임계 성능 저하 구간 ***\n");
    fprintf("FR2에서 FR1 대비 심각한 성능 저하가 발생하는 거리:\n");
    for i = 1:height(critical_distances)
        fprintf("  %d-%dm: SNR 저하 %.2f dB, TP 저하 %.2f%%\n", ...
            critical_distances.distance_min_m(i), ...
            critical_distances.distance_max_m(i), ...
            critical_distances.SNR_degradation_dB(i), ...
            critical_distances.Throughput_degradation_percent(i));
    end
else
    fprintf("\n임계 성능 저하 구간 없음.\n");
end

%% ===== PART 7: 군사용 통신 요구사항 분석 (NEW) =====
fprintf("\n========== PART 7: 군사용 통신 요구사항 충족 분석 ==========\n");

% 군사용 요구사항 출력
fprintf("\n=== 군사용 통신 요구사항 ===\n");
fprintf("최소 SNR: %d dB\n", MILITARY_REQUIREMENTS.min_SNR_dB);
fprintf("최소 Throughput: %d Mbps\n", MILITARY_REQUIREMENTS.min_throughput_Mbps);
fprintf("최소 신뢰도: %.1f%%\n", MILITARY_REQUIREMENTS.min_reliability);
fprintf("목표 커버리지: %.1f%%\n", MILITARY_REQUIREMENTS.coverage_target);

% FR1과 FR2의 군사용 요구사항 충족도 분석
for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    bw = bws(fIdx);
    freq_label = sprintf('%.1f GHz', fc/1e9);
    
    fprintf("\n=== %s 분석 ===\n", freq_label);
    
    % 해당 주파수 데이터 추출
    freq_data = results_heatmap(results_heatmap.fc == fc, :);
    
    % 요구사항 충족 여부 계산
    meets_SNR = freq_data.SNR_dB >= MILITARY_REQUIREMENTS.min_SNR_dB;
    meets_TP = freq_data.Throughput_Mbps >= MILITARY_REQUIREMENTS.min_throughput_Mbps;
    meets_both = meets_SNR & meets_TP;
    
    % 통계
    total_points = height(freq_data);
    SNR_compliance_rate = sum(meets_SNR, 'omitnan') / total_points * 100;
    TP_compliance_rate = sum(meets_TP, 'omitnan') / total_points * 100;
    full_compliance_rate = sum(meets_both, 'omitnan') / total_points * 100;
    
    fprintf("SNR 요구사항 충족률: %.2f%%\n", SNR_compliance_rate);
    fprintf("Throughput 요구사항 충족률: %.2f%%\n", TP_compliance_rate);
    fprintf("전체 요구사항 충족률: %.2f%%\n", full_compliance_rate);
    
    % 목표 달성 여부
    meets_target = full_compliance_rate >= MILITARY_REQUIREMENTS.coverage_target;
    gap_to_target = MILITARY_REQUIREMENTS.coverage_target - full_compliance_rate;
    
    fprintf("목표 커버리지 달성: %s\n", ternary(meets_target, 'YES', 'NO'));
    if ~meets_target
        fprintf("목표까지 부족: %.2f%%\n", gap_to_target);
    end
    
    % 최적화 방안 계산
    fprintf("\n--- 최적화 방안 분석 ---\n");
    
    % 방안 1: 송신 전력 증가
    % 필요한 추가 SNR 계산
    non_compliant_data = freq_data(~meets_both, :);
    if ~isempty(non_compliant_data)
        SNR_shortfall = MILITARY_REQUIREMENTS.min_SNR_dB - non_compliant_data.SNR_dB;
        SNR_shortfall(SNR_shortfall < 0) = 0;
        required_additional_SNR_dB = mean(SNR_shortfall, 'omitnan');
        
        % 송신 전력 증가량 (dB)
        required_power_increase_dB = required_additional_SNR_dB;
        new_Pt_dBm = Pt_dBm + required_power_increase_dB;
        
        fprintf("방안 1 - 송신 전력 증가:\n");
        fprintf("  현재 송신 전력: %.1f dBm\n", Pt_dBm);
        fprintf("  필요 송신 전력: %.1f dBm (+ %.1f dB)\n", new_Pt_dBm, required_power_increase_dB);
        
        % 송신 전력 제한 확인 (일반적으로 43 dBm 이하)
        if new_Pt_dBm > 43
            fprintf("  ⚠️ 경고: 권장 송신 전력 한계 초과 (43 dBm)\n");
            power_feasible = false;
        else
            fprintf("  ✓ 송신 전력 증가 실현 가능\n");
            power_feasible = true;
        end
    else
        required_power_increase_dB = 0;
        new_Pt_dBm = Pt_dBm;
        power_feasible = true;
    end
    
    % 방안 2: 기지국 추가
    % 커버리지 갭을 채우기 위한 추가 BS 수
    if ~meets_target
        coverage_ratio_current = full_compliance_rate / 100;
        coverage_ratio_target = MILITARY_REQUIREMENTS.coverage_target / 100;
        
        if coverage_ratio_current > 0
            additional_BS_needed = ceil(coverage_ratio_target / coverage_ratio_current) - 1;
        else
            additional_BS_needed = Inf;
        end
        
        fprintf("방안 2 - 기지국 추가:\n");
        fprintf("  필요 추가 기지국 수: %d개\n", additional_BS_needed);
        
        % 배치 권장 위치 (미충족 지역의 중심)
        non_compliant_locs = freq_data(~meets_both, {'lat', 'lon'});
        if ~isempty(non_compliant_locs)
            suggested_BS_lat = mean(non_compliant_locs.lat);
            suggested_BS_lon = mean(non_compliant_locs.lon);
            fprintf("  권장 배치 위치 (중심): (%.6f, %.6f)\n", suggested_BS_lat, suggested_BS_lon);
        end
    else
        additional_BS_needed = 0;
        suggested_BS_lat = NaN;
        suggested_BS_lon = NaN;
    end
    
    % 방안 3: 안테나 개선
    fprintf("방안 3 - 안테나 개선:\n");
    fprintf("  현재: %dx%d 안테나 배열\n", bsAntennaSize(1), bsAntennaSize(2));
    suggested_antenna_gain_dB = required_additional_SNR_dB;
    if suggested_antenna_gain_dB > 0
        fprintf("  필요 추가 안테나 이득: %.1f dB\n", suggested_antenna_gain_dB);
        fprintf("  권장: 8x8 또는 16x16 Massive MIMO\n");
    else
        fprintf("  현재 안테나 구성 충분\n");
    end
    
    % 방안 4: 빔포밍 최적화
    fprintf("방안 4 - 빔포밍 최적화:\n");
    fprintf("  권장: 적응형 빔포밍 (Adaptive Beamforming)\n");
    fprintf("  예상 이득: 3-6 dB\n");
    
    % 종합 권장사항
    fprintf("\n--- 종합 권장사항 ---\n");
    if meets_target
        fprintf("✓ 현재 구성으로 군사용 요구사항 충족\n");
        recommendation = "현재 구성 유지";
        priority_1 = "N/A"; priority_2 = "N/A"; priority_3 = "N/A";
    else
        fprintf("최적 솔루션 조합:\n");
        
        % 우선순위 결정
        if power_feasible && required_power_increase_dB < 10
            priority_1 = sprintf("송신 전력 %.1f dB 증가", required_power_increase_dB);
            fprintf("  1순위: 송신 전력 %.1f dB 증가 (%.1f → %.1f dBm)\n", ...
                required_power_increase_dB, Pt_dBm, new_Pt_dBm);
        else
            priority_1 = sprintf("기지국 %d개 추가", additional_BS_needed);
            fprintf("  1순위: 기지국 %d개 추가\n", additional_BS_needed);
        end
        
        priority_2 = "Massive MIMO (8x8 이상) 적용";
        fprintf("  2순위: Massive MIMO 안테나 적용\n");
        
        priority_3 = "적응형 빔포밍 구현";
        fprintf("  3순위: 적응형 빔포밍 기술 적용\n");
        
        recommendation = sprintf("%s + %s", priority_1, priority_2);
    end
    
    % 결과 저장
    mil_row = struct(...
        'frequency_GHz', fc/1e9, ...
        'bandwidth_MHz', bw/1e6, ...
        'SNR_compliance_percent', SNR_compliance_rate, ...
        'throughput_compliance_percent', TP_compliance_rate, ...
        'full_compliance_percent', full_compliance_rate, ...
        'meets_target', meets_target, ...
        'gap_to_target_percent', gap_to_target, ...
        'current_Pt_dBm', Pt_dBm, ...
        'required_Pt_dBm', new_Pt_dBm, ...
        'power_increase_dB', required_power_increase_dB, ...
        'power_increase_feasible', power_feasible, ...
        'additional_BS_needed', additional_BS_needed, ...
        'suggested_BS_lat', suggested_BS_lat, ...
        'suggested_BS_lon', suggested_BS_lon, ...
        'suggested_antenna_gain_dB', suggested_antenna_gain_dB, ...
        'priority_1', priority_1, ...
        'priority_2', priority_2, ...
        'priority_3', priority_3, ...
        'recommendation', recommendation);
    
    military_analysis = [military_analysis; struct2table(mil_row)]; %#ok<AGROW>
end

writetable(military_analysis, outCSV_military);
fprintf("\n군사용 요구사항 분석 결과가 %s 에 저장되었습니다.\n", outCSV_military);

% 군사용 요구사항 충족도 시각화
figure('Name', 'Military Requirements Compliance');

% 충족률 비교
subplot(2,2,1);
compliance_data = [military_analysis.SNR_compliance_percent, ...
                   military_analysis.throughput_compliance_percent, ...
                   military_analysis.full_compliance_percent];
bar(compliance_data);
set(gca, 'XTickLabel', {'FR1 (4.7GHz)', 'FR2 (28GHz)'});
ylabel('Compliance Rate (%)');
legend('SNR', 'Throughput', 'Both', 'Location', 'best');
title('Military Requirements Compliance');
yline(MILITARY_REQUIREMENTS.coverage_target, 'r--', 'Target', 'LineWidth', 2);
ylim([0 100]);
grid on;

% 송신 전력 요구사항
subplot(2,2,2);
power_data = [military_analysis.current_Pt_dBm; military_analysis.required_Pt_dBm]';
bar(power_data);
set(gca, 'XTickLabel', {'FR1 (4.7GHz)', 'FR2 (28GHz)'});
ylabel('Transmit Power (dBm)');
legend('Current', 'Required', 'Location', 'best');
title('Transmit Power Requirements');
yline(43, 'r--', 'Power Limit', 'LineWidth', 2);
grid on;

% 추가 기지국 수
subplot(2,2,3);
bar(military_analysis.additional_BS_needed);
set(gca, 'XTickLabel', {'FR1 (4.7GHz)', 'FR2 (28GHz)'});
ylabel('Number of Additional BS');
title('Additional Base Stations Needed');
grid on;

% 목표 대비 갭
subplot(2,2,4);
bar(military_analysis.gap_to_target_percent);
set(gca, 'XTickLabel', {'FR1 (4.7GHz)', 'FR2 (28GHz)'});
ylabel('Gap to Target (%)');
title('Coverage Gap to Military Target');
yline(0, 'g--', 'Target Met', 'LineWidth', 2);
grid on;

saveas(gcf, 'Military_Requirements_Analysis.png');

% 커버리지 맵에 군사용 요구사항 오버레이
figure('Name', 'Military Compliance Coverage Map');
for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    SNR_map = SNR_maps{fIdx};
    TP_map = TP_maps{fIdx};
    
    % 군사용 요구사항 충족 맵
    military_compliant = (SNR_map >= MILITARY_REQUIREMENTS.min_SNR_dB) & ...
                        (TP_map >= MILITARY_REQUIREMENTS.min_throughput_Mbps);
    
    subplot(1, 2, fIdx);
    imagesc(lon_grid, lat_grid, double(military_compliant));
    set(gca, 'YDir', 'normal');
    colormap(gca, [1 0 0; 0 1 0]); % 빨강=불충족, 초록=충족
    colorbar('Ticks', [0.25, 0.75], 'TickLabels', {'Non-Compliant', 'Compliant'});
    xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('Military Compliance Map - %.1f GHz', fc/1e9));
    hold on;
    plot(bsPosition(2), bsPosition(1), 'b^', 'MarkerSize', 15, 'MarkerFaceColor', 'b');
    
    % 추가 BS 권장 위치 표시 (FR2인 경우)
    if fIdx == 2
        mil_row = military_analysis(military_analysis.frequency_GHz == fc/1e9, :);
        if ~isnan(mil_row.suggested_BS_lat)
            plot(mil_row.suggested_BS_lon, mil_row.suggested_BS_lat, 'yx', ...
                'MarkerSize', 20, 'LineWidth', 3);
            legend('Current BS', 'Suggested Additional BS', 'Location', 'best');
        end
    end
    hold off;
end
saveas(gcf, 'Military_Compliance_Map.png');

%% ===== PART 8: 최종 요약 보고서 =====
fprintf("\n");
fprintf("========================================================\n");
fprintf("              최종 분석 요약 보고서\n");
fprintf("========================================================\n");

fprintf("\n1. 기본 커버리지 성능\n");
fprintf("---------------------\n");
for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    stats_f = coverage_stats(coverage_stats.fc == fc & coverage_stats.SNR_threshold_dB == 15, :);
    fprintf("  %s: %.2f%% 커버리지 (SNR ≥ 15dB)\n", ...
        ternary(fIdx==1, 'FR1 (4.7 GHz)', 'FR2 (28 GHz)'), ...
        stats_f.coverage_ratio_percent);
end

fprintf("\n2. FR2 추가 기지국 요구사항\n");
fprintf("---------------------------\n");
bs_15dB = bs_optimization_results(bs_optimization_results.SNR_threshold_dB == 15, :);
fprintf("  SNR ≥ 15dB 기준:\n");
fprintf("    - FR1 커버리지: %.2f%% (반경 %.1fm)\n", ...
    bs_15dB.FR1_coverage_percent, bs_15dB.FR1_avg_radius_m);
fprintf("    - FR2 커버리지: %.2f%% (반경 %.1fm)\n", ...
    bs_15dB.FR2_coverage_percent, bs_15dB.FR2_avg_radius_m);
fprintf("    - 권장 추가 BS: %d개\n", bs_15dB.recommended_additional_BS);
fprintf("    - 전체 영역 커버를 위한 총 BS:\n");
fprintf("      · FR1: %d개\n", bs_15dB.total_BS_needed_FR1);
fprintf("      · FR2: %d개\n", bs_15dB.total_BS_needed_FR2);

fprintf("\n3. FR2 성능 저하 임계점\n");
fprintf("-----------------------\n");
critical_dist = degradation_analysis(degradation_analysis.is_critical_degradation, :);
if ~isempty(critical_dist)
    fprintf("  심각한 성능 저하 발생 거리:\n");
    for i = 1:min(3, height(critical_dist))
        fprintf("    - %d~%dm: SNR ↓%.2fdB, Throughput ↓%.1f%%\n", ...
            critical_dist.distance_min_m(i), critical_dist.distance_max_m(i), ...
            critical_dist.SNR_degradation_dB(i), ...
            critical_dist.Throughput_degradation_percent(i));
    end
else
    fprintf("  심각한 성능 저하 구간 없음\n");
end

fprintf("\n4. 군사용 통신 요구사항 충족도\n");
fprintf("-------------------------------\n");
fprintf("  요구사항:\n");
fprintf("    - 최소 SNR: %d dB\n", MILITARY_REQUIREMENTS.min_SNR_dB);
fprintf("    - 최소 Throughput: %d Mbps\n", MILITARY_REQUIREMENTS.min_throughput_Mbps);
fprintf("    - 목표 커버리지: %.1f%%\n", MILITARY_REQUIREMENTS.coverage_target);
fprintf("\n  충족 현황:\n");
for fIdx = 1:length(freqs)
    fc = freqs(fIdx);
    mil_row = military_analysis(military_analysis.frequency_GHz == fc/1e9, :);
    fprintf("    %s:\n", ternary(fIdx==1, 'FR1 (4.7 GHz)', 'FR2 (28 GHz)'));
    fprintf("      - 요구사항 충족률: %.2f%%\n", mil_row.full_compliance_percent);
    fprintf("      - 목표 달성: %s\n", ternary(mil_row.meets_target, 'YES ✓', 'NO ✗'));
    if ~mil_row.meets_target
        fprintf("      - 목표 부족분: %.2f%%\n", mil_row.gap_to_target_percent);
    end
end

fprintf("\n5. 최적화 권장사항\n");
fprintf("-------------------\n");
fprintf("  FR1 (4.7 GHz):\n");
mil_FR1 = military_analysis(military_analysis.frequency_GHz == freqs(1)/1e9, :);
fprintf("    %s\n", mil_FR1.recommendation{1});
fprintf("    - 1순위: %s\n", mil_FR1.priority_1{1});
fprintf("    - 2순위: %s\n", mil_FR1.priority_2{1});
fprintf("    - 3순위: %s\n", mil_FR1.priority_3{1});

fprintf("\n  FR2 (28 GHz):\n");
mil_FR2 = military_analysis(military_analysis.frequency_GHz == freqs(2)/1e9, :);
fprintf("    %s\n", mil_FR2.recommendation{1});
fprintf("    - 1순위: %s\n", mil_FR2.priority_1{1});
fprintf("    - 2순위: %s\n", mil_FR2.priority_2{1});
fprintf("    - 3순위: %s\n", mil_FR2.priority_3{1});

if mil_FR2.additional_BS_needed > 0 && ~isnan(mil_FR2.suggested_BS_lat)
    fprintf("\n  FR2 추가 기지국 권장 배치 위치:\n");
    fprintf("    - 중심 좌표: (%.6f, %.6f)\n", ...
        mil_FR2.suggested_BS_lat, mil_FR2.suggested_BS_lon);
end

fprintf("\n6. 핵심 인사이트\n");
fprintf("-----------------\n");
FR1_coverage_15 = bs_15dB.FR1_coverage_percent;
FR2_coverage_15 = bs_15dB.FR2_coverage_percent;
coverage_ratio = FR1_coverage_15 / FR2_coverage_15;
fprintf("  • FR1이 FR2 대비 %.1f배 넓은 커버리지\n", coverage_ratio);
fprintf("  • FR2는 동일 커버리지를 위해 약 %d배의 기지국 필요\n", ...
    bs_15dB.recommended_additional_BS + 1);

% 경제성 분석
BS_cost_estimate = 100000; % 기지국 1대당 비용 (달러, 가정)
FR2_additional_cost = bs_15dB.recommended_additional_BS * BS_cost_estimate;
fprintf("  • FR2 추가 배치 비용 (추정): $%d\n", FR2_additional_cost);

% 송신 전력 비교
if mil_FR2.power_increase_dB > 0
    power_increase_cost_ratio = 10^(mil_FR2.power_increase_dB/10);
    fprintf("  • FR2는 군사용 요구 충족을 위해 %.1f배의 송신 전력 필요\n", ...
        power_increase_cost_ratio);
end

fprintf("\n7. 전략적 제안\n");
fprintf("---------------\n");
if FR2_coverage_15 < 70
    fprintf("  ⚠️ FR2 단독 사용 시 심각한 커버리지 부족\n");
    fprintf("  → 권장: FR1 + FR2 하이브리드 네트워크\n");
    fprintf("      - FR1: 광역 커버리지 담당\n");
    fprintf("      - FR2: 핫스팟/고용량 지역 담당\n");
else
    fprintf("  ✓ FR2 단독 사용 가능 (추가 최적화 필요)\n");
end

if ~mil_FR2.meets_target
    fprintf("\n  군사용 통신의 경우:\n");
    fprintf("  → 단기 솔루션: %s\n", mil_FR2.priority_1{1});
    fprintf("  → 중장기 솔루션: %s + %s\n", mil_FR2.priority_2{1}, mil_FR2.priority_3{1});
end

fprintf("\n========================================================\n");
fprintf("                   분석 완료\n");
fprintf("========================================================\n");

%% ===== 생성된 파일 목록 =====
fprintf("\n생성된 파일:\n");
fprintf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
fprintf("📊 데이터 파일:\n");
fprintf("  1. %s - 대표 포인트 상세 결과\n", outCSV_points);
fprintf("  2. %s - 전체 히트맵 데이터\n", outCSV_heatmap);
fprintf("  3. %s - 커버리지 통계\n", outCSV_coverage);
fprintf("  4. %s - 기지국 최적화 분석 ⭐NEW\n", outCSV_bs_optimization);
fprintf("  5. %s - FR2 성능 저하 분석 ⭐NEW\n", outCSV_degradation);
fprintf("  6. %s - 군사용 요구사항 분석 ⭐NEW\n", outCSV_military);

fprintf("\n📈 시각화 파일:\n");
fprintf("  기본 분석:\n");
fprintf("    • Heatmap_SNR_*.png (2개)\n");
fprintf("    • Heatmap_Throughput_*.png (2개)\n");
fprintf("    • Heatmap_RxPower_*.png (2개)\n");
fprintf("    • SNR_bar.png\n");
fprintf("    • Throughput_bar.png\n");
fprintf("    • DelaySpread_bar.png\n");
fprintf("    • Coverage_Comparison.png\n");
fprintf("\n  고급 분석 ⭐NEW:\n");
fprintf("    • BS_Optimization_Analysis.png - 기지국 최적화\n");
fprintf("    • Coverage_Radius_Comparison.png - 커버리지 반경 비교\n");
fprintf("    • FR2_Performance_Degradation.png - 성능 저하 분석\n");
fprintf("    • Military_Requirements_Analysis.png - 군사용 요구사항\n");
fprintf("    • Military_Compliance_Map.png - 군사용 충족 맵\n");

fprintf("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
fprintf("✅ 모든 분석이 성공적으로 완료되었습니다!\n");
fprintf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n");

%% ===== Helper Function =====
function result = ternary(condition, true_val, false_val)
    % 삼항 연산자 구현
    if condition
        result = true_val;
    else
        result = false_val;
    end
end