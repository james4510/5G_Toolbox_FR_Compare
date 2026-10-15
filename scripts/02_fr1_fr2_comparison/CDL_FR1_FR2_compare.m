%% FR1 vs FR2 커버리지 히트맵 + 대표 포인트 비교 스크립트
% 파일명: FR1_FR2_Coverage_Heatmap.m
% 목적: 
%   1) 전체 영역에 대한 커버리지 히트맵 생성 (SNR, Pr, Throughput)
%   2) 대표 포인트 6개에서 상세 분석
%   3) 커버리지 통계 (커버리지율, 사각지대 등)

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

% OFDM 설정
SCS = 15; NRB = 52;

% 출력 파일명
outCSV_points = "results_FR1_FR2_points.csv";
outCSV_heatmap = "results_FR1_FR2_heatmap.csv";
outCSV_coverage = "results_FR1_FR2_coverage_stats.csv";

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
                'Pr_dBm', Pr_dBm_val, 'SNR_dB', SNR_dB_val, ...
                'Throughput_Mbps', throughput_bps_val/1e6);
            results_heatmap = [results_heatmap; struct2table(row_hm)]; %#ok<AGROW>
        end
    end
    
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

fprintf("\n=== 모든 분석 완료! ===\n");
fprintf("생성된 파일:\n");
fprintf("  - %s (대표 포인트 결과)\n", outCSV_points);
fprintf("  - %s (히트맵 데이터)\n", outCSV_heatmap);
fprintf("  - %s (커버리지 통계)\n", outCSV_coverage);
fprintf("  - Heatmap_*.png (히트맵 이미지들)\n");
fprintf("  - SNR_bar.png, Throughput_bar.png, DelaySpread_bar.png\n");
fprintf("  - Coverage_Comparison.png\n");